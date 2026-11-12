# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

import hashlib
import importlib
import importlib.metadata as metadata
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import klayout.db as kdb
import numpy as np
from packaging.requirements import Requirement
import skrf


def run(*args, cwd, env):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True, timeout=120)
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", file=sys.stderr, flush=True)
    result.check_returncode()
    return result.stdout


def shared_packages():
    return {
        name: (metadata.version(dist), importlib.import_module(name).__file__)
        for name, dist in (
            ("numpy", "numpy"), ("scipy", "scipy"), ("skrf", "scikit-rf"),
            ("klayout.db", "klayout"), ("gmsh", "gmsh"), ("gdsfactory", "gdsfactory"),
        )
    }


def source_hashes(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file()}


def check_export(path):
    layouts = list(path.glob("*.oas")) + list(path.glob("*.gds"))
    assert layouts, f"No exported layouts in {path}"
    for filename in layouts:
        layout = kdb.Layout()
        layout.read(str(filename))
        assert any(not cell.bbox().empty() for cell in layout.top_cells()), filename
    definitions = []
    for filename in path.glob("*.json"):
        data = json.loads(filename.read_text())
        if "gds_file" in data:
            definitions.append(data)
            assert (path / data["gds_file"]).is_file(), data
            assert data["tool"] == "capacitance", data
            assert data["ports"] and data["layers"] and data["sif_names"], data
    assert len(definitions) == 1, definitions
    for name in ("simulation.sh", "scripts/run.py", "scripts/produce_cmatrix_table.py"):
        assert (path / name).stat().st_size > 0, name


assert os.geteuid() != 0, "Run this test as a non-root container user"
assert sys.prefix == sys.base_prefix, "KQCircuits must use the shared Python environment"
root = Path(os.environ.get("TOOLS", "/foss/tools")) / "kqcircuits"
source = root / "klayout_package/python"
assert not os.access(source, os.W_OK), "Installed KQCircuits sources must be read-only to the user"
assert (root / "SOURCES").read_text().startswith("kqcircuits ")
assert metadata.version("kqcircuits") not in ("0.0.0", "0.0.1"), "Git-derived version was lost"
direct_url = json.loads(metadata.distribution("kqcircuits").read_text("direct_url.json"))
assert direct_url["dir_info"]["editable"], direct_url
assert direct_url["url"] == source.as_uri(), direct_url

# Check the current core and sim requirements, without freezing the shared package versions.
for spec in metadata.requires("kqcircuits"):
    requirement = Requirement(spec)
    if requirement.marker is None or requirement.marker.evaluate({"extra": "sim"}):
        assert metadata.version(requirement.name) in requirement.specifier, spec
import qutip  # noqa: E402,F401
import versiontag  # noqa: E402,F401

before_packages = shared_packages()
before_sources = source_hashes(root)
work = Path(tempfile.mkdtemp(prefix="export-", dir=Path.cwd()))
project = work / "project with spaces"
project.mkdir(exist_ok=True)
env = dict(os.environ)
env.pop("KQC_TMP_PATH", None)

# Make unintended GUI, mesher or solver launches observable even if kqc ignores their exit status.
guards = work / "tool-guards"
guards.mkdir(exist_ok=True)
tool_calls = work / "unexpected-tool-calls"
env["KQC_TEST_TOOL_CALLS"] = str(tool_calls)
for name in ("klayout", "gmsh", "ElmerGrid", "ElmerSolver", "ElmerSolver_mpi", "paraview", "mpirun"):
    guard = guards / name
    guard.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$KQC_TEST_TOOL_CALLS"\nexit 99\n')
    guard.chmod(0o755)
env["PATH"] = str(guards) + os.pathsep + env["PATH"]

run("kqc", "--help", cwd=project, env=env)
assert "waveguides_sim_compare.py" in run("kqc", "sim", "ls", cwd=project, env=env)
assert "quick_demo.py" in run("kqc", "mask", "ls", cwd=project, env=env)
run(sys.executable, "-c", "from pathlib import Path; from kqcircuits.defaults import TMP_PATH; "
    "assert TMP_PATH == Path.cwd() / 'kqc-output'", cwd=project, env=env)

command = ("kqc", "sim", "waveguides_sim_compare.py", "--quiet", "--export-only", "--n-guides-range", "1", "1")
run(*command, cwd=project, env=env)
check_export(project / "kqc-output/waveguides_sim_elmer")

env["KQC_TMP_PATH"] = str(work / "custom output")
run(sys.executable, "-c", "import os; from pathlib import Path; from kqcircuits.defaults import TMP_PATH; "
    "assert TMP_PATH == Path(os.environ['KQC_TMP_PATH'])", cwd=project, env=env)
run(*command, "--export-path-basename", "export with spaces", cwd=project, env=env)
check_export(work / "custom output/export with spaces")
assert not tool_calls.exists(), tool_calls.read_text() if tool_calls.exists() else ""

# For a coupled two-port network, terminating the other port in R gives
# Y_in = Y_ii - Y_ij * Y_ji / (Y_jj + 1/R), independently of scikit-rf's Circuit API.
rf_dir = work / "rf"
rf_dir.mkdir(exist_ok=True)
frequencies = np.array([1e9, 2e9])
admittance = np.zeros((2, 2, 2), dtype=complex)
admittance[:, 0, 0] = 0.02 + 1j * np.array([0.01, 0.02])
admittance[:, 1, 1] = 0.01 + 1j * np.array([0.03, 0.06])
admittance[:, 0, 1] = admittance[:, 1, 0] = -0.002j
network = skrf.Network(frequency=skrf.Frequency.from_f(frequencies, unit="Hz"), y=admittance, z0=50)
network.write_touchstone(str(rf_dir / "fixture_project_SMatrix"), form="ri")
run(sys.executable, str(source / "scripts/simulations/post_process/calculate_q_from_s.py"), cwd=rf_dir, env=env)
result = json.loads((rf_dir / "fixture_q.json").read_text())
np.testing.assert_allclose(result["frequencies"], frequencies)
for i in range(2):
    j = 1 - i
    loaded_y = admittance[:, i, i] - admittance[:, i, j] * admittance[:, j, i] / (admittance[:, j, j] + 1 / 50)
    np.testing.assert_allclose(result[f"Q_port{i + 1}"], loaded_y.imag / loaded_y.real, rtol=1e-10)

assert source_hashes(root) == before_sources, "KQCircuits wrote to its installed source tree"
assert shared_packages() == before_packages, "Shared package versions or import locations changed"
print(f"KQCircuits {metadata.version('kqcircuits')} export and scikit-rf {metadata.version('scikit-rf')} postprocessing passed")
