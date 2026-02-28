#!/usr/bin/env python3
# ========================================================================
# Check for newer versions of tools listed in a YAML manifest file
# Uses git ls-remote to query public Git repositories
#
# SPDX-FileCopyrightText: 2025-2026 Harald Pretl
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

import os
import sys
import argparse
import subprocess
import yaml
import re

try:
    from packaging import version
    HAS_PACKAGING = True
except ImportError:
    HAS_PACKAGING = False


def get_repos_from_yaml(yaml_file):
    """Read and parse the YAML metadata file."""
    try:
        with open(yaml_file, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: File {yaml_file} not found.")
        sys.exit(1)
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML file: {exc}")
        sys.exit(1)


def get_tag_prefix(tag):
    """Extract the non-numeric prefix from a tag to identify its 'family'.

    Examples: 'v0.30.6' -> 'v', 'ngspice-45.2' -> 'ngspice-',
              'trilinos-release-12-12-1' -> 'trilinos-release-',
              '2026.02.13' -> '', 'r1.19.1' -> 'r'
    """
    match = re.match(r'^([^0-9]*)', tag)
    return match.group(1) if match else ''


def normalize_version(version_string):
    """Strip the non-numeric prefix from a version string for comparison."""
    return version_string[len(get_tag_prefix(version_string)):]


def is_version_newer(current_tag, latest_tag):
    """Compare two version tags to determine if latest is newer than current."""
    current_norm = normalize_version(current_tag)
    latest_norm = normalize_version(latest_tag)

    # Try semantic versioning comparison if packaging is available
    if HAS_PACKAGING:
        try:
            return version.parse(latest_norm) > version.parse(current_norm)
        except Exception:
            pass

    # Manual version comparison fallback
    try:
        current_parts = [int(x) if x.isdigit() else x for x in re.split(r'[.-]', current_norm)]
        latest_parts = [int(x) if x.isdigit() else x for x in re.split(r'[.-]', latest_norm)]

        max_len = max(len(current_parts), len(latest_parts))
        current_parts.extend([0] * (max_len - len(current_parts)))
        latest_parts.extend([0] * (max_len - len(latest_parts)))

        for i in range(max_len):
            if isinstance(latest_parts[i], int) and isinstance(current_parts[i], int):
                if latest_parts[i] != current_parts[i]:
                    return latest_parts[i] > current_parts[i]
            else:
                if str(latest_parts[i]) != str(current_parts[i]):
                    return str(latest_parts[i]) > str(current_parts[i])

        return False  # Versions are equal
    except Exception:
        return latest_norm > current_norm


def find_latest_tag(tags, current_tag):
    """Find the latest tag that is newer than the current tag."""
    current_prefix = get_tag_prefix(current_tag)

    version_tags = []
    for tag in tags:
        # Skip commit hashes, branch-like names with '/', and non-version names
        if re.match(r'^[0-9a-f]{7,40}$', tag):
            continue
        if '/' in tag:
            continue
        if tag.lower() in ('main', 'master', 'head', 'latest', 'dev', 'development'):
            continue
        # Only consider tags from the same family (same prefix before digits)
        if get_tag_prefix(tag).lower() != current_prefix.lower():
            continue
        if re.search(r'\d', tag):
            version_tags.append(tag)

    if not version_tags:
        return None

    # Sort newest first
    try:
        if HAS_PACKAGING:
            version_tags.sort(key=lambda x: version.parse(normalize_version(x)), reverse=True)
        else:
            version_tags.sort(reverse=True)
    except Exception:
        version_tags.sort(reverse=True)

    # Return the first (newest) tag that is actually newer than current
    for tag in version_tags:
        if is_version_newer(current_tag, tag):
            return tag

    return None


def git_ls_remote_head(repo_url):
    """Get the latest commit on HEAD using git ls-remote."""
    try:
        result = subprocess.run(
            ['git', 'ls-remote', repo_url, 'HEAD'],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip().split()[0]
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return None


def git_ls_remote_tags(repo_url):
    """Get all tag names using git ls-remote."""
    try:
        result = subprocess.run(
            ['git', 'ls-remote', '--tags', repo_url],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            tags = []
            for line in result.stdout.strip().split('\n'):
                parts = line.split('\t')
                if len(parts) == 2 and not parts[1].endswith('^{}'):
                    tags.append(parts[1].replace('refs/tags/', ''))
            return tags
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return []


def check_newer_versions(repos, update_yaml=False, yaml_file=None, tool_filter=None):
    """Check each repo for newer commits/tags and optionally update the YAML.

    If tool_filter is provided (list of tool names), only those tools are checked.
    """
    updates = {}

    # Normalize tool_filter for case-insensitive matching
    if tool_filter:
        tool_filter_lower = [t.lower() for t in tool_filter]
    else:
        tool_filter_lower = None

    # Validate tool_filter against known tool names
    if tool_filter_lower:
        known_names = {repo['name'].lower() for repo in repos}
        for t in tool_filter_lower:
            if t not in known_names:
                print(f"Warning: Tool '{t}' not found in YAML metadata.")

    for repo in repos:
        name = repo['name']
        if tool_filter_lower and name.lower() not in tool_filter_lower:
            continue
        repo_url = repo['repo']
        current_version = str(repo['commit'])

        if not repo_url.rstrip('/').endswith('.git'):
            print(f"Skipping non-git repository: {repo_url}")
            continue

        if re.match(r'^[0-9a-f]{40}$', current_version):
            latest_commit = git_ls_remote_head(repo_url)
            if latest_commit is None:
                print(f"Error: Could not fetch latest commit for {name}")
                continue

            if current_version != latest_commit:
                print(f"Repository: {name}, Current Commit: {current_version}, Newer Commit: {latest_commit}")
                updates[name] = latest_commit

        else:
            tags = git_ls_remote_tags(repo_url)
            if not tags:
                print(f"Warning: Could not fetch tags for {name}")
                continue

            latest_tag = find_latest_tag(tags, current_version)
            if latest_tag:
                print(f"Repository: {name}, Current Tag: {current_version}, Newer Tag: {latest_tag}")
                updates[name] = latest_tag

    if update_yaml and yaml_file and updates:
        write_updates_to_yaml(yaml_file, updates)


def write_updates_to_yaml(yaml_file, updates):
    """Write updated commit hashes/tags back into the YAML file."""
    try:
        with open(yaml_file, 'r') as f:
            repos = yaml.safe_load(f)
    except (FileNotFoundError, yaml.YAMLError) as e:
        print(f"Error reading YAML file for update: {e}")
        return

    changed = sum(1 for repo in repos if repo.get('name') in updates)
    if changed == 0:
        return

    for repo in repos:
        if repo.get('name') in updates:
            repo['commit'] = updates[repo['name']]

    try:
        with open(yaml_file, 'w') as f:
            yaml.dump(repos, f, default_flow_style=False, sort_keys=False)
        print(f"\nUpdated {changed} entries in {yaml_file}")
    except IOError as e:
        print(f"Error writing YAML file: {e}")


if __name__ == "__main__":
    default_yaml = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               '..', 'tool_metadata.yml')

    prs = argparse.ArgumentParser(
        description="Check for newer versions of tools from a YAML manifest file."
    )
    prs.add_argument("yaml_file", type=str, nargs='?', default=default_yaml,
                     help="Path to the YAML metadata file (default: tool_metadata.yml)")
    prs.add_argument("-u", "--update-yaml", action="store_true",
                     help="Write newer commits/tags back into the YAML file")
    prs.add_argument("-t", "--tools", nargs='+', metavar="TOOL",
                     help="Only check/update these tools (space-separated list)")

    args = prs.parse_args()
    repos = get_repos_from_yaml(args.yaml_file)
    check_newer_versions(repos,
                         update_yaml=args.update_yaml,
                         yaml_file=args.yaml_file,
                         tool_filter=args.tools)