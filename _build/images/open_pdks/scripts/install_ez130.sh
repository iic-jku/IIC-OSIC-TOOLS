#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail

PDK_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PDK="ihp-sg13g2"
LIB_NAME="${EZ130_LIBRARY_NAME:-ez130_8t}"
PAGE_URL="${EZ130_PAGE_URL:-https://iip.ethz.ch/ez-library/ihp130-8t.html}"
ARCHIVE_URL="${EZ130_ARCHIVE_URL:-}"
TARGET_LIB_DIR="${PDK_ROOT}/${PDK}/libs.ref/${LIB_NAME}"
IHP_STDCELL_LEF="${PDK_ROOT}/${PDK}/libs.ref/sg13g2_stdcell/lef/sg13g2_tech.lef"

if [ ! -d "${PDK_ROOT}/${PDK}/libs.ref" ]; then
    echo "[ERROR] ${PDK_ROOT}/${PDK}/libs.ref not found. Please run install_ihp.sh first."
    exit 1
fi

if [ -d "${TARGET_LIB_DIR}" ]; then
    echo "[INFO] ${LIB_NAME} already installed at ${TARGET_LIB_DIR}, skipping."
    exit 0
fi

EZ130_TMPDIR=$(mktemp -d)
trap 'rm -rf "${EZ130_TMPDIR}"' EXIT

download_url() {
    local url=$1 dst=$2
    python3 - "$url" "$dst" <<'PYEOF'
import sys
import shutil
import urllib.request

url, dst = sys.argv[1:3]
with urllib.request.urlopen(url, timeout=60) as src, open(dst, "wb") as out:
    shutil.copyfileobj(src, out)
PYEOF
}

resolve_archive_candidates() {
    python3 - "$PAGE_URL" "$ARCHIVE_URL" <<'PYEOF'
import html.parser
import os
import sys
import urllib.parse
import urllib.request

page_url, archive_url = sys.argv[1:3]
if archive_url:
    print(archive_url)
    raise SystemExit

class LinkParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "a":
            return
        href = dict(attrs).get("href")
        if href:
            self.links.append(href)

with urllib.request.urlopen(page_url, timeout=60) as src:
    page_html = src.read().decode("utf-8", "replace")

parser = LinkParser()
parser.feed(page_html)

archive_exts = (".zip", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar")
preferred = []
fallback = []
seen = set()

def add(url):
    if url not in seen:
        print(url)
        seen.add(url)

for href in parser.links:
    full = urllib.parse.urljoin(page_url, href)
    lowered_path = urllib.parse.urlparse(full).path.lower()
    if not lowered_path.endswith(archive_exts):
        continue
    if any(token in lowered_path for token in ("ez130", "ihp130", "8t")):
        preferred.append(full)
    else:
        fallback.append(full)

for url in preferred + fallback:
    add(url)

page_dir = urllib.parse.urljoin(page_url, ".")
for guess in (
    "ihp130-8t.zip",
    "ihp130-8t.tar.gz",
    "ez130-8t.zip",
    "ez130-8t.tar.gz",
):
    add(urllib.parse.urljoin(page_dir, guess))
PYEOF
}

extract_archive() {
    local archive=$1 dest=$2
    python3 - "$archive" "$dest" <<'PYEOF'
import os
import pathlib
import shutil
import sys
import tarfile
import zipfile

archive, dest = sys.argv[1:3]
path = pathlib.Path(archive)
dest_path = pathlib.Path(dest)
dest_path.mkdir(parents=True, exist_ok=True)

def is_safe_member(name: str) -> bool:
    pure = pathlib.PurePosixPath(name)
    return not pure.is_absolute() and ".." not in pure.parts

def safe_link_source(name: str, linkname: str) -> pathlib.Path:
    base = pathlib.PurePosixPath(name).parent
    target = pathlib.PurePosixPath(linkname)
    if target.is_absolute():
        raise SystemExit(f"Unsafe EZ130 archive link target: {linkname}")
    target = pathlib.PurePosixPath(base, target)
    if ".." in target.parts:
        raise SystemExit(f"Unsafe EZ130 archive link target: {linkname}")
    return dest_path / pathlib.Path(*target.parts)

name = path.name.lower()
if name.endswith(".zip"):
    with zipfile.ZipFile(path) as zf:
        for member in zf.infolist():
            if not is_safe_member(member.filename):
                raise SystemExit(f"Unsafe EZ130 zip archive member: {member.filename}")
            zf.extract(member, dest_path)
elif name.endswith((".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar")):
    with tarfile.open(path) as tf:
        members = tf.getmembers()
        deferred_links = []
        for member in members:
            if not is_safe_member(member.name):
                raise SystemExit(f"Unsafe EZ130 tar archive member: {member.name}")
            member_path = dest_path / member.name
            if member.isdir():
                member_path.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                member_path.parent.mkdir(parents=True, exist_ok=True)
                with tf.extractfile(member) as src, open(member_path, "wb") as out:
                    shutil.copyfileobj(src, out)
            elif member.issym() or member.islnk():
                safe_link_source(member.name, member.linkname)
                deferred_links.append(member)
            else:
                raise SystemExit(f"Unsupported EZ130 tar archive member: {member.name}")
        for member in deferred_links:
            member_path = dest_path / member.name
            member_path.parent.mkdir(parents=True, exist_ok=True)
            if member.issym():
                os.symlink(member.linkname, member_path)
            else:
                os.link(safe_link_source(member.name, member.linkname), member_path)
else:
    raise SystemExit(f"Unsupported EZ130 archive format: {archive}")
PYEOF
}

find_library_dir() {
    python3 - "$1" "$LIB_NAME" <<'PYEOF'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
libname = sys.argv[2]

def looks_like_stdcell(path: pathlib.Path) -> bool:
    needed = [path / sub for sub in ("lib", "lef", "verilog", "spice", "cdl")]
    return all(p.is_dir() for p in needed) and (path / "lef" / f"{libname}.lef").exists()

candidates = []
for path in root.rglob(libname):
    if path.is_dir() and path.name == libname:
        candidates.append(path)
for path in root.rglob("libs.ref"):
    candidate = path / libname
    if candidate.is_dir():
        candidates.append(candidate)

seen = set()
for candidate in candidates:
    resolved = str(candidate.resolve())
    if resolved in seen:
        continue
    seen.add(resolved)
    if looks_like_stdcell(candidate):
        print(candidate)
        raise SystemExit

print(f"Could not locate {libname} in extracted EZ130 archive under {root}", file=sys.stderr)
raise SystemExit(1)
PYEOF
}

find_companion_dir() {
    python3 - "$1" "$2" <<'PYEOF'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
suffix = pathlib.PurePosixPath(sys.argv[2]).as_posix()

for path in root.rglob(pathlib.PurePosixPath(suffix).name):
    if path.is_dir() and path.as_posix().endswith(suffix):
        print(path)
        raise SystemExit
raise SystemExit(3)
PYEOF
}

echo "[INFO] Installing ETH Zurich ${LIB_NAME} library into ${PDK}."

ARCHIVE_CANDIDATES=$(resolve_archive_candidates)
if [ -z "${ARCHIVE_CANDIDATES}" ]; then
    echo "[ERROR] Could not determine an EZ130 archive URL from ${PAGE_URL}."
    exit 1
fi

ARCHIVE_PATH=""
while IFS= read -r candidate; do
    [ -n "${candidate}" ] || continue
    echo "[INFO] Trying EZ130 archive ${candidate}"
    archive_name=$(basename "${candidate%%\?*}")
    [ -n "${archive_name}" ] || archive_name="ez130-archive"
    if download_url "${candidate}" "${EZ130_TMPDIR}/${archive_name}"; then
        ARCHIVE_PATH="${EZ130_TMPDIR}/${archive_name}"
        break
    fi
    echo "[WARN] Could not download ${candidate}"
done <<EOF
${ARCHIVE_CANDIDATES}
EOF

if [ -z "${ARCHIVE_PATH}" ]; then
    echo "[ERROR] Failed to download EZ130 from ${PAGE_URL} or any derived archive URL."
    exit 1
fi

EXTRACT_DIR="${EZ130_TMPDIR}/extract"
extract_archive "${ARCHIVE_PATH}" "${EXTRACT_DIR}"

SOURCE_LIB_DIR=$(find_library_dir "${EXTRACT_DIR}")
echo "[INFO] Copying ${SOURCE_LIB_DIR} to ${TARGET_LIB_DIR}"
mkdir -p "$(dirname "${TARGET_LIB_DIR}")"
cp -a "${SOURCE_LIB_DIR}" "${TARGET_LIB_DIR}"

SOURCE_LIBRELANE_DIR=""
if SOURCE_LIBRELANE_DIR=$(find_companion_dir "${EXTRACT_DIR}" "libs.tech/librelane/${LIB_NAME}"); then
    :
else
    status=$?
    if [ "${status}" -ne 3 ]; then
        exit "${status}"
    fi
    SOURCE_LIBRELANE_DIR=""
fi
if [ -n "${SOURCE_LIBRELANE_DIR}" ]; then
    TARGET_LIBRELANE_DIR="${PDK_ROOT}/${PDK}/libs.tech/librelane/${LIB_NAME}"
    echo "[INFO] Copying ${SOURCE_LIBRELANE_DIR} to ${TARGET_LIBRELANE_DIR}"
    mkdir -p "$(dirname "${TARGET_LIBRELANE_DIR}")"
    cp -a "${SOURCE_LIBRELANE_DIR}" "${TARGET_LIBRELANE_DIR}"
fi

if [ ! -e "${TARGET_LIB_DIR}/lef/sg13g2_tech.lef" ] && [ -e "${IHP_STDCELL_LEF}" ]; then
    echo "[INFO] Reusing sg13g2_tech.lef for ${LIB_NAME}"
    cp -a "${IHP_STDCELL_LEF}" "${TARGET_LIB_DIR}/lef/sg13g2_tech.lef"
fi

if [ -d "${TARGET_LIB_DIR}/lib" ]; then
    echo "[INFO] Compressing EZ130 Liberty files."
    find "${TARGET_LIB_DIR}/lib" -name "*.lib" -type f -exec gzip -k -f {} +
    find "${TARGET_LIB_DIR}/lib" -name "*.lib" -type l | while read -r lib_link; do
        [ -e "${lib_link}.gz" ] && continue
        link_target=$(readlink "${lib_link}")
        case "${link_target}" in
            /*) target_gz="${link_target}.gz" ;;
            *)  target_gz="$(dirname "${lib_link}")/${link_target}.gz" ;;
        esac
        if [ -e "${target_gz}" ]; then
            ln -s "${link_target}.gz" "${lib_link}.gz"
        fi
    done
fi

if [ -d "${TARGET_LIBRELANE_DIR:-}" ]; then
    while IFS= read -r cfg; do
        sed -i 's/\.lib\([^A-Za-z0-9_.]\|$\)/.lib.gz\1/g' "${cfg}"
    done < <(grep -rl '\.lib' "${TARGET_LIBRELANE_DIR}" || true)
fi

echo "[INFO] EZ130 installation complete: ${TARGET_LIB_DIR}"
