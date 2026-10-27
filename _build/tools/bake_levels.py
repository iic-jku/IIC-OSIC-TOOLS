#!/usr/bin/env python3
# ========================================================================
# Split the bake targets into build levels for a staged CI build
#
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
# ========================================================================
#
# Reads the output of `docker buildx bake --print all` (resolved with
# DEPS_FROM_TARGETS=1, so dependencies show up as "target:<name>" contexts)
# and prints one `<level>=<JSON list>` line per level, ready to append to
# $GITHUB_OUTPUT:
#
#   base, base-dev, tools-1 .. tools-N, image-full
#
# Every target of a level depends only on targets of earlier levels, so the
# levels can be built one after the other with DEPS_FROM_TARGETS=0. The
# levels come from the named contexts, not from the tools-level-* groups.

import argparse
import json
import sys

FIXED = ("base", "base-dev", "image-full")


def target_deps(targets):
    """Map each target to the set of targets it uses as a named context."""
    deps = {}
    for name, spec in targets.items():
        ctxs = (spec.get("contexts") or {}).values()
        deps[name] = {c[len("target:"):] for c in ctxs if c.startswith("target:")}
    return deps


def depths(deps):
    """Longest dependency chain below each target (0 = no dependencies)."""
    result = {}

    def visit(name, stack):
        if name in result:
            return result[name]
        if name in stack:
            print(f"[ERROR] Dependency cycle: {' -> '.join(stack + [name])}")
            sys.exit(1)
        if name not in deps:
            print(f"[ERROR] Target <{stack[-1]}> depends on unknown target <{name}>.")
            sys.exit(1)
        result[name] = 1 + max((visit(d, stack + [name]) for d in deps[name]), default=-1)
        return result[name]

    for name in deps:
        visit(name, [])
    return result


def levels(targets, max_tool_levels):
    deps = target_deps(targets)
    for name in FIXED:
        if name not in deps:
            print(f"[ERROR] Target <{name}> missing from the bake output.")
            sys.exit(1)
    depth = depths(deps)

    # Tool levels count from base-dev (depth 1): a tool on base-dev or on
    # base only is level 1, a tool on a level 1 tool is level 2, and so on.
    tools = {}
    for name in deps:
        if name in FIXED:
            continue
        tools.setdefault(max(1, depth[name] - 1), []).append(name)

    n_levels = max(tools, default=0)
    if n_levels > max_tool_levels:
        print(f"[ERROR] {n_levels} tool levels, the workflow has jobs for {max_tool_levels}. "
              f"Add a tools-{n_levels} job to the nightly workflow.")
        sys.exit(1)

    out = {"base": ["base"], "base-dev": ["base-dev"]}
    for lvl in range(1, max_tool_levels + 1):
        out[f"tools-{lvl}"] = sorted(tools.get(lvl, []))
    out["image-full"] = ["image-full"]
    return out


if __name__ == "__main__":
    prs = argparse.ArgumentParser(
        description="Split the targets of `docker buildx bake --print all` into build levels.")
    prs.add_argument("bake_json", nargs="?", default="-",
                     help="File with the bake --print output (default: stdin).")
    prs.add_argument("--max-tool-levels", type=int, default=4,
                     help="Number of tool levels the workflow has jobs for (default: 4).")
    args = prs.parse_args()

    if args.bake_json == "-":
        bake = json.load(sys.stdin)
    else:
        with open(args.bake_json) as f:
            bake = json.load(f)

    for key, names in levels(bake["target"], args.max_tool_levels).items():
        print(f"{key}={json.dumps(names, separators=(',', ':'))}")
