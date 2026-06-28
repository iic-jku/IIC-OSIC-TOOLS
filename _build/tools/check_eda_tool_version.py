#!/usr/bin/env python3
# ========================================================================
# Check for newer versions of EDA tool packages (and optionally update
# them). Supports packages installed via PIP (PyPI), Cargo (crates.io),
# and Gem (RubyGems).
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

import argparse
import sys
import os
import re
import requests

from packaging import version

# crates.io rejects requests without a descriptive User-Agent, so identify
# ourselves on every request (harmless for PyPI and RubyGems).
USER_AGENT = ("iic-osic-tools-version-check "
              "(+https://github.com/iic-jku/IIC-OSIC-TOOLS)")
HEADERS = {'User-Agent': USER_AGENT}

# A version is a sequence of dot-separated numbers (e.g. 1, 1.2, 0.1.7).
VERSION_RE = r'\d+(?:\.\d+)*'


def _logical_lines(content):
    """Join shell line-continuations ('\\' at end of line) into logical lines."""
    lines = []
    buf = ''
    for raw in content.splitlines():
        stripped = raw.rstrip()
        if stripped.endswith('\\'):
            buf += stripped[:-1] + ' '
        else:
            buf += stripped
            lines.append(buf.strip())
            buf = ''
    if buf:
        lines.append(buf.strip())
    return lines


def _parse_pip(content):
    """Extract (name, version) pairs for PIP packages from a shell script.

    Handles quoted entries with extras like "amaranth[builtin-yosys]==0.5.8".
    """
    matches = re.findall(
        r'([\w][\w\-]*(?:\[[^\]]*\])?)=='     # package name with optional extras
        r'(' + VERSION_RE + r')',             # version
        content
    )
    # Strip extras brackets for PyPI lookups (e.g. "amaranth[builtin-yosys]").
    return [('pip', re.sub(r'\[.*\]', '', pkg), ver) for pkg, ver in matches]


def _parse_cargo(content):
    """Extract (name, version) pairs from `cargo install` invocations.

    Recognizes both `crate --version X.Y.Z` and `crate@X.Y.Z` forms.
    """
    packages = []
    for line in _logical_lines(content):
        if 'cargo install' not in line:
            continue
        # crate followed by a version flag
        packages += [('cargo', name, ver) for name, ver in re.findall(
            r'([A-Za-z0-9_][A-Za-z0-9_\-]*)\s+(?:--version|--vers)\s+'
            r'(' + VERSION_RE + r')', line)]
        # crate@version form
        packages += [('cargo', name, ver) for name, ver in re.findall(
            r'([A-Za-z0-9_][A-Za-z0-9_\-]*)@(' + VERSION_RE + r')', line)]
    return packages


def _parse_gem(content):
    """Extract (name, version) pairs from `gem install` invocations.

    Gems may be unpinned (version is None), pinned via `-v`/`--version VER`,
    or via the `name:VER` form.
    """
    packages = []
    for line in _logical_lines(content):
        if 'gem install' not in line:
            continue
        # Take the tokens following 'gem install'.
        tokens = line.split()
        try:
            start = tokens.index('install', tokens.index('gem')) + 1
        except ValueError:
            continue
        tokens = tokens[start:]

        i = 0
        while i < len(tokens):
            tok = tokens[i]
            if tok in ('-v', '--version'):
                # Version flag applies to the previously seen gem.
                if i + 1 < len(tokens) and packages and packages[-1][0] == 'gem':
                    name = packages[-1][1]
                    packages[-1] = ('gem', name, tokens[i + 1])
                i += 2
                continue
            if tok.startswith('-'):
                # Unknown flag; skip it (and ignore any argument heuristically).
                i += 1
                continue
            if ':' in tok:
                name, _, ver = tok.partition(':')
                packages.append(('gem', name, ver or None))
            else:
                packages.append(('gem', tok, None))
            i += 1
    return packages


def get_installed_packages(shell_script):
    """Extract (ecosystem, name, version) triples from a shell script."""
    try:
        with open(shell_script, 'r') as file:
            content = file.read()
    except FileNotFoundError:
        print(f"[ERROR] File {shell_script} not found.")
        sys.exit(1)

    return _parse_pip(content) + _parse_cargo(content) + _parse_gem(content)


def _latest_pypi(package):
    response = requests.get(
        f'https://pypi.org/pypi/{package}/json', headers=HEADERS, timeout=15)
    if response.status_code != 200:
        print(f"[ERROR] Could not fetch {package} from PyPI "
              f"(HTTP {response.status_code}).")
        return None
    return response.json()['info']['version']


def _latest_crates(package):
    response = requests.get(
        f'https://crates.io/api/v1/crates/{package}', headers=HEADERS, timeout=15)
    if response.status_code != 200:
        print(f"[ERROR] Could not fetch {package} from crates.io "
              f"(HTTP {response.status_code}).")
        return None
    crate = response.json()['crate']
    # Prefer the newest stable release, fall back to the newest overall.
    return crate.get('max_stable_version') or crate.get('newest_version')


def _latest_rubygems(package):
    response = requests.get(
        f'https://rubygems.org/api/v1/versions/{package}/latest.json',
        headers=HEADERS, timeout=15)
    if response.status_code != 200:
        print(f"[ERROR] Could not fetch {package} from RubyGems "
              f"(HTTP {response.status_code}).")
        return None
    ver = response.json().get('version')
    # RubyGems returns "unknown" when it has no published version.
    return None if not ver or ver == 'unknown' else ver


_FETCHERS = {
    'pip': _latest_pypi,
    'cargo': _latest_crates,
    'gem': _latest_rubygems,
}


def get_latest_version(ecosystem, package):
    """Query the relevant registry for the latest version of a package.

    Returns the latest version string, or None on error.
    """
    try:
        return _FETCHERS[ecosystem](package)
    except requests.RequestException as e:
        print(f"[ERROR] Network error for {package}: {e}")
        return None
    except (ValueError, KeyError) as e:
        print(f"[ERROR] Unexpected response for {package}: {e}")
        return None


def is_newer(latest_version, current_version):
    """Return True if latest_version is strictly newer than current_version."""
    try:
        return version.parse(latest_version) > version.parse(current_version)
    except Exception:
        # Fallback to string comparison
        return current_version != latest_version


def check_newer_versions(packages):
    """Query each registry and report newer (or, for unpinned gems, available) versions."""
    for ecosystem, package, current_version in packages:
        latest_version = get_latest_version(ecosystem, package)
        if latest_version is None:
            continue

        if current_version is None:
            # Unpinned (e.g. gems installed without a version constraint).
            print(f"Package: {package} ({ecosystem}), not pinned, "
                  f"Latest Version: {latest_version}")
        elif is_newer(latest_version, current_version):
            print(f"Package: {package} ({ecosystem}), Current Version: "
                  f"{current_version}, Newer Version: {latest_version}")


def _update_pattern(ecosystem, package):
    """Build a regex that matches `package <version>` for the given ecosystem.

    Group 1 is everything up to and including the separator, group 2 is the
    version, so a substitution of r'\\g<1>NEWVERSION' replaces only the version.
    """
    name = re.escape(package)
    if ecosystem == 'pip':
        return re.compile(r'(' + name + r'(?:\[[^\]]*\])?==)(' + VERSION_RE + r')')
    if ecosystem == 'cargo':
        return re.compile(r'(' + name + r'\s+(?:--version|--vers)\s+|'
                          + name + r'@)(' + VERSION_RE + r')')
    if ecosystem == 'gem':
        return re.compile(r'(' + name + r'\s+(?:-v|--version)\s+|'
                          + name + r':)(' + VERSION_RE + r')')
    raise ValueError(f"Unknown ecosystem: {ecosystem}")


def update_version_in_file(file_path, ecosystem, package, new_version, dry_run=False):
    """Update the version of a package in the shell script (in-place).

    Returns True if the version was changed, False otherwise.
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except (FileNotFoundError, IOError) as e:
        print(f"[ERROR] Could not read {file_path}: {e}")
        return False

    pattern = _update_pattern(ecosystem, package)
    match = pattern.search(content)
    if not match:
        print(f"[ERROR] Could not find pinned version for {package} "
              f"({ecosystem}) in {file_path}")
        return False

    old_version = match.group(2)
    if old_version == new_version:
        return False  # already up-to-date

    new_content = pattern.sub(rf'\g<1>{new_version}', content, count=1)

    if not dry_run:
        try:
            with open(file_path, 'w') as f:
                f.write(new_content)
        except IOError as e:
            print(f"[ERROR] Could not write {file_path}: {e}")
            return False

    print(f"  {package} ({ecosystem}): {old_version} -> {new_version}")
    return True


def update_versions(shell_script, packages, tool_filter=None, dry_run=False):
    """Check each registry and update pinned versions in the shell script.

    If tool_filter is given (list of package names), only those packages
    are considered for updating.
    """
    errors = 0
    updated = 0

    for ecosystem, package, current_version in packages:
        # If a tool filter is specified, skip packages not in the list.
        if tool_filter and package not in tool_filter:
            continue

        # Unpinned packages have no version to update in place.
        if current_version is None:
            continue

        latest_version = get_latest_version(ecosystem, package)
        if latest_version is None:
            errors += 1
            continue

        if is_newer(latest_version, current_version):
            if update_version_in_file(shell_script, ecosystem, package,
                                      latest_version, dry_run=dry_run):
                updated += 1
            else:
                errors += 1

    if updated > 0:
        action = "would be updated" if dry_run else "updated"
        print(f"\n{updated} package(s) {action}.")
    else:
        print("\nAll packages are up-to-date.")

    if errors > 0:
        print(f"{errors} error(s) occurred during processing.")
        sys.exit(1)


if __name__ == "__main__":
    default_script = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  '..', 'tool_eda.sh')

    prs = argparse.ArgumentParser(
        description="Check for newer versions of EDA tool packages installed "
                    "via PIP, Cargo, or Gem (and optionally update them in "
                    "tool_eda.sh).")
    prs.add_argument("script", nargs="?", default=default_script,
                     help="Path to the shell script with the packages "
                          f"(default: {default_script}).")
    prs.add_argument("-u", "--update", action="store_true",
                     help="Update the pinned tool versions in the shell script.")
    prs.add_argument("-t", "--tools", nargs="+", metavar="PKG",
                     help="Only update the specified packages (used with -u).")
    prs.add_argument("--dry-run", action="store_true",
                     help="Show what would be updated without writing changes.")

    args = prs.parse_args()

    installed_packages = get_installed_packages(args.script)

    if args.update:
        print(f'Updating versions in: "{args.script}"')
        if args.tools:
            print(f"Filtering packages: {', '.join(args.tools)}")
        update_versions(args.script, installed_packages,
                        tool_filter=args.tools, dry_run=args.dry_run)
    else:
        check_newer_versions(installed_packages)
