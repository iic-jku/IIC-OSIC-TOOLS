#!/usr/bin/env python3
# ========================================================================
# Update tool versions from YAML manifest file
#
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
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

import argparse
import glob
import sys

import yaml
try:
    from yaml import CLoader as Loader
except ImportError:
    from yaml import Loader


# --- YAML metadata helpers ------------------------------------------------

def metadata_read(path):
    """Read raw content from a YAML metadata file."""
    try:
        with open(path, mode="r") as f:
            return f.read()
    except (FileNotFoundError, IOError) as e:
        print(f"Error reading metadata file: {e}")
        return None


def metadata_parse(raw_data):
    """Parse YAML metadata and warn about near-duplicate tool names."""
    data = yaml.load(raw_data, Loader=Loader)
    normalized_set = set()
    for x in data:
        norm_str = x['name'].replace('-', '_')
        if norm_str in normalized_set:
            print("WARNING: there are similar entries in the input yaml file "
                  "('-' and '_' are interpreted as the same symbol)")
            break
        normalized_set.add(norm_str)
    return data


def get_revision(data, tool_name):
    """Look up the commit/revision for a given tool name."""
    result = [x for x in data
              if x['name'].replace('-', '_') == tool_name.replace('-', '_')]
    if len(result) < 1:
        return None
    if len(result) > 1:
        print(f"WARNING: Multiple entries for tool {tool_name} found!")
    commit = result[0].get("commit")
    return str(commit) if commit is not None else None


# --- Dockerfile helpers ---------------------------------------------------

def read_dockerfile(path="Dockerfile"):
    """Read a Dockerfile and return its lines."""
    try:
        with open(path, mode="r") as f:
            return f.readlines()
    except (FileNotFoundError, IOError) as e:
        print(f"Error reading Dockerfile '{path}': {e}")
        return None


def write_dockerfile(df_contents, path="Dockerfile"):
    """Write lines back to a Dockerfile."""
    try:
        with open(path, mode="w") as f:
            f.writelines(df_contents)
    except IOError as e:
        print(f"Error writing Dockerfile '{path}': {e}")


def get_existing_tools(df_contents):
    """Extract tool names from ARG …_REPO_COMMIT lines in a Dockerfile."""
    tools = set()
    for line in df_contents:
        elements = line.split()
        if len(elements) >= 2 and elements[0].upper() == "ARG":
            arg_str = elements[1].split("=")[0].strip()
            if arg_str.endswith("REPO_COMMIT"):
                tool_name = arg_str.removesuffix("_REPO_COMMIT").lower()
                tools.add(tool_name)
    return list(tools)


def update_revision(df_contents, tool_name, new_rev):
    """Update the REPO_COMMIT ARG for a tool in a Dockerfile (in-place).

    Returns True if the line was changed, False if not found or already up-to-date.
    """
    search_str = tool_name.upper().replace("-", "_") + "_REPO_COMMIT"
    new_line = f'ARG {search_str}="{new_rev}"\n'
    for i, line in enumerate(df_contents):
        elem = line.split()
        if len(elem) >= 2 and elem[0].upper() == "ARG" and elem[1].startswith(search_str):
            if df_contents[i] == new_line:
                return True  # already up-to-date
            df_contents[i] = new_line
            print(f"  {tool_name}: updated to {new_rev}")
            return True
    return False


# --- Main -----------------------------------------------------------------

if __name__ == "__main__":
    prs = argparse.ArgumentParser(
        description="Update the tool commits/revisions from a local yaml file "
                    "(e.g.: tool_metadata.yml)")
    prs.add_argument("--dry-run", action="store_true",
                     help="Disable writing the Dockerfile, just print the results.")
    prs.add_argument("--dockerfiles", action="store", type=str,
                     default="images/*/Dockerfile*",
                     help="Path pattern for Dockerfiles (supports wildcards).")
    prs.add_argument("--metadata-path", action="store", type=str,
                     default="tool_metadata.yml",
                     help="Change the location of the tool_metadata.yml input file.")

    args = prs.parse_args()

    print(f"Loading tool metadata from: \"{args.metadata_path}\"")
    raw_meta = metadata_read(args.metadata_path)
    if raw_meta is None:
        print(f"Error: Could not read metadata from \"{args.metadata_path}\"")
        sys.exit(1)

    data = metadata_parse(raw_meta)
    errors = 0

    # Find all Dockerfiles matching the pattern
    dockerfile_paths = glob.glob(args.dockerfiles)
    if not dockerfile_paths:
        print(f"No Dockerfiles found matching the pattern: \"{args.dockerfiles}\"")
        sys.exit(1)

    for dockerfile_path in dockerfile_paths:
        df_contents = read_dockerfile(path=dockerfile_path)
        if df_contents is not None:
            tools = get_existing_tools(df_contents)
            updated = False
            for tool in tools:
                new_rev = get_revision(data, tool)
                if new_rev is not None:
                    if not update_revision(df_contents, tool, new_rev):
                        print(f"ERROR: updating the revision for {tool} in {dockerfile_path} failed!")
                        errors += 1
                    else:
                        updated = True
            if updated and not args.dry_run:
                write_dockerfile(df_contents, path=dockerfile_path)

    if errors > 0:
        print(f"\n{errors} error(s) occurred during processing.")
        sys.exit(1)