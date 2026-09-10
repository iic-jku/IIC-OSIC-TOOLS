#!/usr/bin/env python3
# ========================================================================
# File browser that opens every design file with its matching tool
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
#
# Usage: sak-open.py [-h] [--all] [--prune <name>] [--refresh <s>] [--list]
#                    [<root>]
# ========================================================================

"""One button per design file; click it and the right tool opens it.

    sak-open.py [root] [options]

Scans the tree for the extensions below and puts up a window with one button per
file, labelled with the file name and grouped by directory. Pressing a button
launches

    .sch .sym                        xschem
    .gds .gds.gz .oas .oas.gz        klayout -e        (edit mode)
    .mag                             magic
    .vcd .fst .gtkw                  gtkwave
    .raw                             gaw               (ngspice rawfile)
    .png .pdf                        xdg-open          (the desktop's handler)
    everything textual               gvim              (RTL, SPICE decks, flow
                                                       collateral, Makefiles,
                                                       scripts, prose)

in the file's own directory, so xschem finds its `simulations/` and every tool
resolves relative paths as it would from a shell there. It needs a display, so
run it in the VNC/noVNC desktop or over X11 forwarding, not in a shell-only
container.

Schematics and symbols of one design unit share a single tabbed xschem
instance rather than getting one process per click, remote-controlled through
xschem's TCP interface. The unit is found from the clicked file's directory:
without an xschemrc the directory stands alone, with one the nearest ancestor
holding a Makefile (the macro root in the IIC design templates) is the unit,
and when no such ancestor exists up to a .git boundary or `$DESIGNS`, the
xschemrc's directory is. Directories grouped this way should pin netlist_dir
in their xschemrc files, so every tab writes its simulations to one agreed
place. `SAK_OPEN_GROUP_MARKERS` replaces the Makefile marker with a
comma-separated list of file names, `SAK_OPEN_NO_GROUP=1` turns the sharing
off entirely.

Without an argument it scans `$DESIGNS`, falling back to the current directory
when that is unset.

Hovering a button reports the file's size and age in the status line, plus a
marker when it is a symlink or not writable. Clicking a directory heading folds
it away. The right mouse button opens a menu:

    Cell view       every view of one cell -- `gate.sch`, `gate.sym`,
                    `gate.gds`, `gate.nl.v` -- wherever in the tree they live,
                    and whether or not their type is ticked. Right-click any of
                    them and untick it to get the whole tree back.
    Scope here      rescan from the clicked file's directory, which is how a
                    tree too big for `--max` becomes workable. "Back to full
                    tree" returns to the root the program started with.
    Save view       remember the folded directories and the ticked types for
                    this tree in ~/.config/sak-open.json (XDG_CONFIG_HOME is
                    honoured), and "Restore view" puts them back.
    Open shell      a terminal in the file's directory.
    Copy path       the path on the clipboard, absolute or root-relative.

The tree is rescanned every 15 s (`--refresh`), so a file a flow run or a save
creates appears on its own; the window is only rebuilt when the list actually
changed, and keeps its scroll position when it is. Anything that appeared or
was rewritten since the last scan is shown in bold for a minute, which makes a
running flow visible as it lands.

Build outputs are skipped by default -- a LibreLane `runs/` tree alone can hold
ten times more GDS than the design does. `--all` walks everything, `--prune
NAME` adds a directory name to the skip list.

At most `--max` buttons (400) are drawn at once, because each one is an X
window and an X server refuses to allocate a few hundred more. What is left
out is stated at the end of the list and in the status line; narrowing the
filter or unticking a few types brings it into view.

Each viewer command can be overridden from the environment, e.g.

    SAK_OPEN_SV='code -w' sak-open.py

The same file types are wired into the desktop's MIME database, so double
clicking one in Thunar opens the same tool (see
`skel/usr/share/mime/packages/iic-osic-tools-types.xml` and
`skel/usr/share/applications/mimeapps.list` in the image sources).
"""
import argparse
import json
import os
import shlex
import socket
import subprocess
import sys
import time
import tkinter as tk
from pathlib import Path
from tkinter import font as tkfont
from tkinter import ttk

# The design tree, which is what the container mounts and what a user means by
# "my files". The current directory is the fallback, so the script is still
# useful outside a started container.
DEFAULT_ROOT = Path(os.environ.get("DESIGNS") or os.getcwd())

# One entry per tool: the command (a token list, the file name is appended as
# its last argument), the label colour its files get, and the extensions it
# takes. Order decides the order of the checkboxes.
TOOLS = (
    (["xschem"], "#1a6b2f", (".sch", ".sym")),
    (["klayout", "-e"], "#7a3d00", (".gds", ".gds.gz", ".oas", ".oas.gz")),
    # .mag only: magic cannot read a gzipped layout, and unpacking one here
    # would leave a .mag and a stale .mag.gz side by side, which is how edits
    # get lost. Unpack it yourself and open the result.
    (["magic"], "#b06000", (".mag",)),
    (["gtkwave"], "#6a1b7a", (".vcd", ".fst", ".gtkw")),
    (["gaw"], "#1f6f8a", (".raw",)),
    # No image or PDF viewer is installed, so hand these to the desktop's
    # registered handler -- which means they open only under a real session
    # (the noVNC/VNC desktop), not over a bare X forward.
    (["xdg-open"], "#8a2a4a", (".png", ".pdf")),
    # Everything textual, which is everything else: RTL, decks, flow collateral,
    # scripts and prose all open in the same editor.
    (
        ["gvim"],
        "#123a8a",
        (
            ".sv", ".svh", ".v", ".vh", ".vhd", ".vhdl",
            ".spice", ".cir", ".sp", ".cdl",
            ".sdc", ".lef", ".lib", ".tcl", ".mk", ".yaml", ".json",
            ".py", ".qmd", ".tex",
            ".md",
            # A whole file name rather than a suffix, see ext_of().
            "Makefile",
        ),
    ),
)

# Flattened to per-key viewer, colour and environment override. The override
# for `.gds.gz` is SAK_OPEN_GDS_GZ, the one for `Makefile` is SAK_OPEN_MAKEFILE.
VIEWERS = {
    key: {
        "cmd": list(cmd),
        "env": "SAK_OPEN_" + key.lstrip(".").replace(".", "_").upper(),
        "color": color,
    }
    for cmd, color, keys in TOOLS
    for key in keys
}

# The terminal the right-click menu opens, and its override.
TERMINAL = ["xfce4-terminal"]
TERMINAL_ENV = "SAK_OPEN_TERMINAL"

# Marker files whose directory roots a design unit for xschem instance
# sharing, the override for that list, and the switch that turns the sharing
# off altogether. See group_root().
GROUP_MARKERS = "Makefile"
GROUP_MARKERS_ENV = "SAK_OPEN_GROUP_MARKERS"
NO_GROUP_ENV = "SAK_OPEN_NO_GROUP"

# Where "Save view" keeps the folded directories, per scanned tree.
CONFIG = Path(
    os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config"
) / "sak-open.json"

# Directories that hold generated output rather than sources.
PRUNE = {
    ".git",
    ".svn",
    ".worktrees",
    "__pycache__",
    ".venv",
    "node_modules",
    "runs",  # LibreLane
    "sim_build",  # cocotb
    "obj_dir",  # Verilator
    "simulations",  # xschem/ngspice scratch
    "_freeze",  # Quarto's rendered-output cache
}


def ext_of(path):
    """The VIEWERS key `path` matches, or None.

    A key beginning with a dot is a suffix, anything else is a whole file name
    (`Makefile`, which carries no extension at all). Suffixes are tried longest
    first, because they are not all single-component: `foo.gds.gz` has to land
    on `.gds.gz` and not on the `.gz` that `Path.suffix` would hand back.
    Matching is case-insensitive throughout, so `makefile` counts too.
    """
    name = path.name.lower()
    for key in sorted(VIEWERS, key=len, reverse=True):
        if key.startswith("."):
            if name.endswith(key) and len(name) > len(key):
                return key
        elif name == key.lower():
            return key
    return None


def cell_name(path):
    """The cell a file is a view of: its name up to the first dot.

    A cell name carries no dot, everything after the first one qualifies the
    view -- `ble_tx.gds`, `ble_tx.klayout.gds` and `ble_tx.nl.v` are three
    views of `ble_tx`, and `dco.gds.gz` is one of `dco`. A name that starts
    with a dot has no cell and stands for itself.
    """
    return path.name.split(".", 1)[0] or path.name


def human_age(seconds):
    """A rough "how long ago", which is what a flow run makes you ask."""
    if seconds < 10:
        return "just now"
    for limit, div, unit in (
        (90, 1, "s"),
        (5400, 60, "min"),
        (2 * 86400, 3600, "h"),
        (14 * 86400, 86400, "days"),
        (60 * 86400, 7 * 86400, "weeks"),
        (2 * 365 * 86400, 30 * 86400, "months"),
    ):
        if seconds < limit:
            return f"{round(seconds / div)} {unit} ago"
    return f"{round(seconds / (365 * 86400))} years ago"


def human_size(count):
    """Byte count as something readable in a status line."""
    for unit in ("B", "KiB", "MiB", "GiB"):
        if count < 1024 or unit == "GiB":
            return f"{count:.0f} {unit}" if unit == "B" else f"{count:.1f} {unit}"
        count /= 1024.0
    return f"{count:.1f} GiB"  # unreachable, keeps the return type obvious


def terminal_cmd():
    """The terminal emulator, overridable like the viewers."""
    override = os.environ.get(TERMINAL_ENV)
    return shlex.split(override) if override else list(TERMINAL)


def viewer_cmd(ext):
    """Command tokens for `ext`, honouring the environment override."""
    spec = VIEWERS[ext]
    override = os.environ.get(spec["env"])
    return shlex.split(override) if override else list(spec["cmd"])


def group_root(directory):
    """The directory whose xschem instance the files in `directory` share.

    Without an xschemrc the directory stands alone: the stock configuration
    makes netlists land next to wherever xschem starts, so directories must
    not share an instance. With an xschemrc, the nearest ancestor holding a
    group marker (a Makefile, which is the macro root in the IIC design
    templates) is the unit whose files share one instance. No marker up to a
    .git boundary, $DESIGNS or the filesystem root means the xschemrc's own
    directory is the unit. Directories grouped by a marker are expected to
    pin netlist_dir in their xschemrc files, so every tab of the shared
    instance writes its simulations to one agreed place.
    """
    if not (directory / "xschemrc").is_file():
        return directory
    markers = [
        m for m in os.environ.get(GROUP_MARKERS_ENV, GROUP_MARKERS).split(",") if m
    ]
    designs = os.environ.get("DESIGNS")
    stop = Path(designs).resolve() if designs else None
    ancestor = directory
    while True:
        if any((ancestor / marker).exists() for marker in markers):
            return ancestor
        boundary = (ancestor / ".git").exists() or ancestor == stop
        if boundary or ancestor.parent == ancestor:
            return directory
        ancestor = ancestor.parent


def free_port():
    """An unused TCP port. The small race until xschem binds it is accepted."""
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def read_config():
    """The saved views, or an empty one. A damaged file is not fatal here."""
    try:
        with open(CONFIG, encoding="utf-8") as handle:
            saved = json.load(handle)
    except FileNotFoundError:
        return {}
    return saved if isinstance(saved, dict) else {}


def write_config(saved):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    # Write beside the target and rename, so an interrupted save cannot leave
    # a half-written file where the next start expects JSON.
    scratch = CONFIG.with_suffix(".tmp")
    with open(scratch, "w", encoding="utf-8") as handle:
        json.dump(saved, handle, indent=2, sort_keys=True)
        handle.write("\n")
    scratch.replace(CONFIG)


def stamps_of(paths):
    """Modification time per path, 0 for anything that just went away."""
    stamps = {}
    for path in paths:
        try:
            stamps[path] = path.stat().st_mtime
        except OSError:
            stamps[path] = 0.0
    return stamps


def scan(root, prune, exts):
    """Return the matching files below `root`, sorted by relative path."""
    hits = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in prune and not d.startswith(".git"))
        for name in filenames:
            path = Path(dirpath) / name
            if ext_of(path) in exts:
                hits.append(path)
    return sorted(hits, key=lambda p: (str(p.parent).lower(), p.name.lower()))


class Launcher:
    """The window: a filter row, a scrolling wall of buttons, a status line."""

    COL_WIDTH = 240  # px of button grid per column
    EXT_WIDTH = 78  # px per extension checkbox
    MAX_COLUMNS = 6

    # Every file is a Tk button, and every Tk button is an X window with its own
    # pixmaps. Past a few hundred the X server runs out and kills the process
    # outright -- not an exception one can catch, but
    #
    #     X Error of failed request:  BadAlloc (insufficient resources ...)
    #     Major opcode of failed request:  53 (X_CreatePixmap)
    #
    # on stderr and no window at all. A tree of 781 files reproduces it; 567
    # does not. So stop well short of that and say what was left out. Raise it
    # with --max if your X server can take it, --max 0 to remove the limit.
    MAX_BUTTONS = 400

    # How long a file that appeared or changed under us stays highlighted.
    FRESH_SECONDS = 60

    def __init__(self, root_dir, prune, initial_exts, refresh=15.0, max_buttons=None):
        self.root_dir = root_dir
        self.prune = prune
        self.max_buttons = self.MAX_BUTTONS if max_buttons is None else max_buttons
        self.refresh_ms = int(refresh * 1000)
        self.refresh_job = None
        self.files = []
        self.found = {}  # extension -> how many the last scan turned up
        self.procs = []
        self.xschem_groups = {}  # group_root -> {"proc": ..., "port": ...}

        self.win = tk.Tk()
        self.win.title(f"sak-open - {root_dir}")
        self.win.geometry("1000x700")

        self.filter_var = tk.StringVar()
        self.filter_var.trace_add("write", lambda *_: self.populate())
        self.ext_vars = {
            ext: tk.BooleanVar(value=ext in initial_exts) for ext in VIEWERS
        }
        self.status_var = tk.StringVar(value="")
        self.resting_status = ""  # what the status line returns to after a hover
        self.grid_cols = 0  # button columns currently laid out; set by populate()
        self.cell = None  # cell whose views are on screen, None for the whole tree
        self.full_root = root_dir  # what --root asked for; root_dir follows the scope
        self.folded = set()  # directories collapsed to their heading
        self.stamps = {}  # path -> mtime at the last scan, to spot what changed
        self.fresh = {}  # path -> when it stops being highlighted
        self.fresh_job = None

        # Bold marks a directory heading and a file that just changed; plain is
        # named rather than left to the default so the two are distinguishable
        # from the outside (a widget with no font set reports the default one).
        self.plain = tkfont.nametofont("TkDefaultFont").copy()
        self.bold = tkfont.nametofont("TkDefaultFont").copy()
        self.bold.configure(weight="bold")

        self._build_controls()
        self._build_scroller()
        self._build_status()
        self._build_menu()

        self.rescan()
        if self.refresh_ms:
            self.refresh_job = self.win.after(self.refresh_ms, self._auto_refresh)

    # -- widgets ---------------------------------------------------------
    def _build_controls(self):
        # Two rows, because one does not survive a narrow window: the filter and
        # the buttons stay put, the extension boxes below them reflow.
        bar = ttk.Frame(self.win, padding=(8, 6, 8, 2))
        bar.pack(fill="x")

        ttk.Label(bar, text="Filter:").pack(side="left")
        ttk.Button(bar, text="Rescan", command=self.rescan).pack(side="right")
        self.none_btn = ttk.Button(
            bar, text="None", width=5, command=lambda: self.set_all_exts(False)
        )
        self.none_btn.pack(side="right", padx=(2, 8))
        self.all_btn = ttk.Button(
            bar, text="All", width=4, command=lambda: self.set_all_exts(True)
        )
        self.all_btn.pack(side="right", padx=2)
        # width=8 so the entry can shrink; expand gives it the leftover space.
        self.entry = ttk.Entry(bar, textvariable=self.filter_var, width=8)
        self.entry.pack(side="left", fill="x", expand=True, padx=(4, 12))
        self.entry.focus_set()
        self.entry.bind("<Escape>", lambda _e: self.filter_var.set(""))

        self.ext_box = ttk.Frame(self.win, padding=(8, 0, 8, 6))
        self.ext_box.pack(fill="x")
        self.ext_boxes = []
        self.ext_cols = 0
        self.ext_box.bind("<Configure>", lambda e: self._reflow_exts(e.width))

    def _sync_ext_boxes(self, found):
        """One checkbox per extension the tree actually holds, carrying its count.

        VIEWERS knows 20-odd extensions and no single tree carries them all;
        showing the empty ones would be three rows of dead boxes. The count
        rides on the label because 20-odd of them do not fit in a status line.

        Alphabetical, not in VIEWERS order: the boxes are something to find a
        known extension in, and grouping them by tool only helps if you already
        know which tool opens it.
        """
        for box in self.ext_boxes:
            box.destroy()
        self.ext_boxes = [
            ttk.Checkbutton(
                self.ext_box,
                text=f"{ext} ({found[ext]})",
                variable=self.ext_vars[ext],
                command=self.populate,
            )
            for ext in sorted(ext for ext in VIEWERS if found.get(ext))
        ]
        self.ext_cols = 0  # force the regrid below
        self._reflow_exts(self.ext_box.winfo_width() or self.win.winfo_width())
        self._sync_controls()  # a rescan during cell view rebuilds these boxes

    def _reflow_exts(self, width):
        """Re-grid the extension checkboxes into as many columns as `width` holds."""
        if not self.ext_boxes:
            return
        cols = max(1, min(len(self.ext_boxes), int(width) // self.EXT_WIDTH))
        if cols == self.ext_cols:
            return  # a no-op regrid would retrigger <Configure> forever
        self.ext_cols = cols
        for col in range(self.ext_box.grid_size()[0]):
            self.ext_box.columnconfigure(col, weight=0, uniform="")
        for i, box in enumerate(self.ext_boxes):
            box.grid(row=i // cols, column=i % cols, sticky="w", padx=2)
        for col in range(cols):
            self.ext_box.columnconfigure(col, weight=1, uniform="ext")

    def set_all_exts(self, state):
        for var in self.ext_vars.values():
            var.set(state)
        self.populate()

    def _build_scroller(self):
        outer = ttk.Frame(self.win)
        outer.pack(fill="both", expand=True)

        self.canvas = tk.Canvas(outer, highlightthickness=0)
        vbar = ttk.Scrollbar(outer, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=vbar.set)
        vbar.pack(side="right", fill="y")
        self.canvas.pack(side="left", fill="both", expand=True)

        self.inner = ttk.Frame(self.canvas, padding=(8, 4))
        self.window_id = self.canvas.create_window((0, 0), window=self.inner, anchor="nw")
        self.inner.bind(
            "<Configure>",
            lambda _e: self.canvas.configure(scrollregion=self.canvas.bbox("all")),
        )
        self.canvas.bind("<Configure>", self._on_canvas_resize)
        # X11 sends wheel events as buttons 4/5, macOS/Windows as <MouseWheel>.
        self.win.bind_all("<Button-4>", lambda _e: self.canvas.yview_scroll(-3, "units"))
        self.win.bind_all("<Button-5>", lambda _e: self.canvas.yview_scroll(3, "units"))
        self.win.bind_all(
            "<MouseWheel>",
            lambda e: self.canvas.yview_scroll(-1 * (e.delta // 120 or e.delta), "units"),
        )

    def _on_canvas_resize(self, event):
        self.canvas.itemconfigure(self.window_id, width=event.width)
        if self._columns() != self.grid_cols:  # only when it changes: a rebuild is not free
            self.populate()

    def _columns(self):
        """How many button columns fit; one on a window too narrow for more."""
        width = self.canvas.winfo_width() or int(self.win.winfo_width() or self.COL_WIDTH)
        return max(1, min(self.MAX_COLUMNS, width // self.COL_WIDTH))

    def _build_status(self):
        ttk.Separator(self.win).pack(fill="x")
        ttk.Label(
            self.win, textvariable=self.status_var, padding=(8, 4), anchor="w"
        ).pack(fill="x")

    def _build_menu(self):
        """The right-click menu. One instance, re-aimed at whatever was clicked."""
        self.menu = tk.Menu(self.win, tearoff=0)
        self.cell_var = tk.BooleanVar(value=False)
        self.menu.add_checkbutton(
            label="Cell view", variable=self.cell_var, command=self.toggle_cell
        )
        self.menu.add_command(label="Open shell", command=self.open_shell)
        self.menu.add_separator()
        self.menu.add_command(label="Scope here", command=self.scope_here)
        self.menu.add_command(label="Back to full tree", command=self.unscope)
        self.menu.add_command(label="Fold all", command=lambda: self.fold_all(True))
        self.menu.add_command(label="Unfold all", command=lambda: self.fold_all(False))
        self.menu.add_separator()
        self.menu.add_command(label="Save view", command=self.save_view)
        self.menu.add_command(label="Restore view", command=self.restore_view)
        self.menu.add_separator()
        self.menu.add_command(label="Copy path", command=self.copy_path)
        self.menu.add_command(
            label="Copy relative path", command=lambda: self.copy_path(relative=True)
        )
        self.menu_path = None

    def popup_menu(self, event, path):
        self.menu_path = path
        self.status_var.set(self.describe(path))  # the click moved focus off the hover
        self.menu.entryconfigure(
            "Back to full tree",
            state="normal" if self.root_dir != self.full_root else "disabled",
        )
        try:
            self.menu.tk_popup(event.x_root, event.y_root)
        finally:
            self.menu.grab_release()

    # -- data ------------------------------------------------------------
    def rescan(self):
        self._load(scan(self.root_dir, self.prune, set(VIEWERS)))
        self.populate()

    def _load(self, files, stamps=None):
        self.files = files
        stamps = stamps_of(files) if stamps is None else stamps
        # Only from the second scan on: on the first one everything is "new",
        # and a window that opens entirely in bold says nothing.
        if self.stamps:
            until = time.time() + self.FRESH_SECONDS
            for path, mtime in stamps.items():
                if self.stamps.get(path) != mtime:
                    self.fresh[path] = until
            self._schedule_expiry()
        self.stamps = stamps
        found = {}
        for path in files:
            found[ext_of(path)] = found.get(ext_of(path), 0) + 1
        self.found = found
        self._sync_ext_boxes(found)

    def is_fresh(self, path):
        return self.fresh.get(path, 0) > time.time()

    def _schedule_expiry(self):
        """Redraw when the oldest highlight runs out, so bold does expire."""
        if self.fresh_job is not None:
            self.win.after_cancel(self.fresh_job)
            self.fresh_job = None
        if not self.fresh:
            return
        delay = max(0.0, min(self.fresh.values()) - time.time())
        self.fresh_job = self.win.after(int(delay * 1000) + 200, self._expire)

    def _expire(self):
        self.fresh_job = None
        now = time.time()
        self.fresh = {p: t for p, t in self.fresh.items() if t > now}
        self.populate()
        self._schedule_expiry()

    def _auto_refresh(self):
        """Pick up files created or deleted outside the window.

        A rebuild scrolls back to the top and drops the hover, so it happens
        only when the file list really changed -- a flow run finishing, a new
        schematic saved. An unchanged tree costs one os.walk and nothing else.
        """
        try:
            files = scan(self.root_dir, self.prune, set(VIEWERS))
            stamps = stamps_of(files)
            # Also on mtime, not just on the list: a file rewritten in place by
            # a flow run has to light up too, and the list does not move.
            if files != self.files or stamps != self.stamps:
                where = self.canvas.yview()[0]
                self._load(files, stamps)
                self.populate()
                self.canvas.yview_moveto(where)
        finally:
            self.refresh_job = self.win.after(self.refresh_ms, self._auto_refresh)

    def populate(self):
        for child in self.inner.winfo_children():
            child.destroy()

        wanted = {ext for ext, var in self.ext_vars.items() if var.get()}
        needle = self.filter_var.get().strip().lower()

        groups = {}
        for path in self.files:
            if self.cell:
                if cell_name(path) != self.cell:
                    continue
            else:
                if ext_of(path) not in wanted:
                    continue
                if needle and needle not in str(path.relative_to(self.root_dir)).lower():
                    continue
            rel = path.relative_to(self.root_dir)
            groups.setdefault(rel.parent, []).append(path)

        self.group_dirs = set(groups)  # what "Fold all" acts on
        matched = sum(len(v) for v in groups.values())
        hidden = sum(len(v) for d, v in groups.items() if d in self.folded)
        openable = matched - hidden
        budget = openable if not self.max_buttons else min(openable, self.max_buttons)

        shown = 0
        self.grid_cols = cols = self._columns()
        heading = self.bold
        for rel_dir in sorted(groups, key=lambda p: str(p).lower()):
            folded = rel_dir in self.folded
            if shown >= budget and not folded:
                # Out of budget: draw nothing for this one, but keep going --
                # a folded directory further down still needs its heading, or
                # there would be no way left to click it open.
                continue
            # The heading is a label of our own so it can be clicked; a folded
            # group keeps it and drops the buttons, which is what makes folding
            # cheap in X resources as well as in screen space.
            mark = "▸" if folded else "▾"
            label = ttk.Label(
                self.inner,
                text=f"{mark} {rel_dir}  ({len(groups[rel_dir])})",
                font=heading,
                cursor="hand2",
            )
            label.bind("<Button-1>", lambda _e, d=rel_dir: self.toggle_fold(d))
            if folded:
                # Packed on its own, not as the label of an empty LabelFrame:
                # such a frame collapses to a hairline and clips the heading,
                # which leaves a stray white line and nothing to click.
                label.pack(anchor="w", padx=6, pady=3)
                continue
            frame = ttk.LabelFrame(self.inner, labelwidget=label, padding=(6, 4))
            frame.pack(fill="x", expand=True, pady=3)
            for col in range(cols):
                frame.columnconfigure(col, weight=1, uniform="files")
            for i, path in enumerate(groups[rel_dir][: budget - shown]):
                button = tk.Button(
                    frame,
                    text=path.name,
                    anchor="w",
                    fg=VIEWERS[ext_of(path)]["color"],
                    font=self.bold if self.is_fresh(path) else self.plain,
                    command=lambda p=path: self.open(p),
                )
                button.grid(row=i // cols, column=i % cols, sticky="ew", padx=2, pady=2)
                # Hovering reports size, age and anything odd about the file;
                # the right button opens a shell there or copies the path.
                button.bind("<Enter>", lambda _e, p=path: self.status_var.set(self.describe(p)))
                button.bind("<Leave>", lambda _e: self.status_var.set(self.resting_status))
                button.bind("<Button-3>", lambda e, p=path: self.popup_menu(e, p))
                shown += 1

        if not shown:
            ttk.Label(
                self.inner, text="(no files match)", padding=(4, 8), font=heading
            ).pack(anchor="w")
        elif shown < openable:
            ttk.Label(
                self.inner,
                text=f"... {openable - shown} more not shown, narrow the filter "
                f"(or raise --max, currently {self.max_buttons})",
                padding=(4, 8),
                font=heading,
            ).pack(anchor="w")

        total = sum(n for ext, n in self.found.items() if ext in wanted)
        of_types = f"{len(wanted & set(self.found))} of {len(self.found)} types"
        # The root belongs here: with the paths gone from the hover line, this
        # is the only place that says which tree is on screen.
        folded_note = (
            f", {hidden} in {len(self.folded & set(groups))} folded" if hidden else ""
        )
        capped = f", {openable - shown} held back by --max" if shown < openable else ""
        capped += folded_note
        if self.cell:
            self.set_status(
                f"cell view: {self.cell}, {shown} view{'' if shown == 1 else 's'}"
                f"{capped}   (right-click a view to leave)   in {self.root_dir}"
            )
        else:
            self.set_status(
                f"{shown} of {total} files shown, {of_types} selected{capped}"
                f"   in {self.root_dir}"
            )
        self.canvas.yview_moveto(0.0)

    # -- actions ---------------------------------------------------------
    def set_status(self, text):
        """Set the status line, and make it the text a hover reverts to."""
        self.resting_status = text
        self.status_var.set(text)

    def describe(self, path):
        """How big the file is, when it last changed, and what is odd about it.

        No path: the button carries the name, the group heading carries the
        directory, and the menu copies the full thing. What is left is what
        neither of those shows.
        """
        link = path.is_symlink()
        try:
            info = path.stat()  # follows the link: the size and date that matter
        except OSError:
            return "broken symlink" if link else "(gone)"
        parts = [
            human_size(info.st_size),
            time.strftime("%Y-%m-%d %H:%M", time.localtime(info.st_mtime))
            + f" ({human_age(max(0.0, time.time() - info.st_mtime))})",
        ]
        if link:
            parts.append(f"symlink -> {os.readlink(path)}")
        if not os.access(path, os.W_OK):
            parts.append("read only")
        return "   ".join(parts)

    def copy_path(self, relative=False):
        """Put the clicked file's path on the clipboard.

        Relative to the scanned root for the form that goes into a Makefile or
        a testbench, absolute for the one that goes into a shell.
        """
        if self.menu_path is None:
            return
        text = str(
            self.menu_path.relative_to(self.root_dir) if relative else self.menu_path
        )
        self.win.clipboard_clear()
        self.win.clipboard_append(text)
        # X11 hands out the selection from the owning process, so this lives
        # only as long as the window does unless a clipboard manager runs.
        self.set_status(f"copied  {text}")

    def toggle_cell(self):
        """Show every view of one cell, or go back to the whole tree.

        The views of a cell live in different directories and under different
        types -- schematic, symbol, layout, netlist -- so this deliberately
        ignores both the filter box and the type checkboxes while it is on.
        """
        self.cell = cell_name(self.menu_path) if self.cell_var.get() else None
        if self.cell_var.get() and self.menu_path is None:
            self.cell_var.set(False)
        self._sync_controls()
        self.populate()

    def scope_here(self):
        """Rescan from the clicked file's directory instead of the whole tree."""
        if self.menu_path is not None:
            self._rescope(self.menu_path.parent)

    def unscope(self):
        self._rescope(self.full_root)

    def _rescope(self, root):
        if root == self.root_dir:
            return
        self.root_dir = root
        self.win.title(f"sak-open - {root}")
        # A different tree: no cell selected, nothing folded, and nothing is
        # "new" yet -- the next scan is the baseline, not a wave of changes.
        self.cell = None
        self.cell_var.set(False)
        self.folded.clear()
        self.stamps = {}
        self.fresh.clear()
        self._sync_controls()
        self.rescan()

    def save_view(self):
        """Persist the folded directories and the ticked types for this tree.

        Keyed by the scanned root, so a scoped view and the full tree keep
        their own, and two designs do not overwrite each other.
        """
        picked = sorted(ext for ext, var in self.ext_vars.items() if var.get())
        try:
            saved = read_config()
            saved.setdefault("views", {})[str(self.root_dir)] = {
                "folded": sorted(str(d) for d in self.folded),
                "types": picked,
            }
            write_config(saved)
        except (OSError, ValueError) as exc:
            self.set_status(f"cannot write {CONFIG}: {exc}")
        else:
            self.set_status(
                f"saved {len(self.folded)} folded directories and {len(picked)} types"
                f" to {CONFIG}"
            )

    def restore_view(self):
        try:
            saved = read_config().get("views", {}).get(str(self.root_dir))
        except (OSError, ValueError) as exc:
            self.set_status(f"cannot read {CONFIG}: {exc}")
            return
        if not isinstance(saved, dict):
            self.set_status(f"no saved view for {self.root_dir} in {CONFIG}")
            return
        self.folded = {Path(d) for d in saved.get("folded", [])}
        picked = saved.get("types")
        if picked is not None:
            # Only what this build still knows; a type dropped from VIEWERS
            # since the save must not resurrect a checkbox that cannot exist.
            for ext, var in self.ext_vars.items():
                var.set(ext in picked)
        where = self.canvas.yview()[0]
        self.populate()
        self.canvas.yview_moveto(where)
        self.set_status(
            f"restored {len(self.folded)} folded directories"
            f"{'' if picked is None else f' and {len(picked)} types'} from {CONFIG}"
        )

    def toggle_fold(self, rel_dir):
        """Collapse a directory to its heading, or open it again."""
        self.folded.symmetric_difference_update({rel_dir})
        where = self.canvas.yview()[0]
        self.populate()
        self.canvas.yview_moveto(where)

    def fold_all(self, folded):
        """Collapse or open every directory on screen at once."""
        self.folded = set(self.group_dirs) if folded else set()
        self.populate()
        self.canvas.yview_moveto(0.0)

    def _sync_controls(self):
        """Grey out what cell view ignores, so it reads as inert, not broken."""
        state = "disabled" if self.cell else "normal"
        for widget in (self.entry, self.all_btn, self.none_btn, *self.ext_boxes):
            widget.configure(state=state)

    def open_shell(self):
        """Terminal in the directory of the file the menu was opened on."""
        if self.menu_path is None:
            return
        where = self.menu_path.parent
        # --working-directory rather than cwd=: xfce4-terminal usually hands the
        # request to an already running instance, and that one opens the window
        # in its own working directory, not in ours.
        self.launch(terminal_cmd() + [f"--working-directory={where}"], where, str(where))

    def open(self, path):
        cmd = viewer_cmd(ext_of(path))
        if cmd[0] == "xschem" and not os.environ.get(NO_GROUP_ENV):
            self.open_xschem(cmd, path)
            return
        self.launch(
            cmd + [path.name],
            path.parent,
            f"in {path.parent.relative_to(self.root_dir)}",
        )

    def open_xschem(self, cmd, path):
        """Open `path` as a tab of its design unit's shared xschem instance.

        The first file of a unit starts xschem with a remote-control port and
        the tabbed interface, every later one is handed to that instance as a
        load_new_window command. A unit whose instance was closed, or one that
        does not answer on its port, gets a fresh instance.
        """
        group = group_root(path.parent)
        entry = self.xschem_groups.get(group)
        if entry and entry["proc"].poll() is None:
            if self.xschem_send(entry["port"], f"xschem load_new_window {{{path}}}"):
                self.set_status(f"{path.name}   (tab in the {group.name} xschem)")
                return
        port = free_port()
        proc = self.launch(
            cmd
            + [
                "--tcl",
                f"set xschem_listen_port {port}; set tabbed_interface 1",
                path.name,
            ],
            path.parent,
            f"in {path.parent.relative_to(self.root_dir)}",
        )
        if proc is not None:
            self.xschem_groups[group] = {"proc": proc, "port": port}

    def xschem_send(self, port, command, wait=4.0):
        """Send a remote command, giving a starting instance time to listen.

        True when the command reached the instance. The wait covers the gap
        between launching xschem and its server socket coming up, in which a
        click on a second file of the unit would otherwise fork a stray
        second instance.
        """
        deadline = time.monotonic() + wait
        while True:
            try:
                with socket.create_connection(
                    ("127.0.0.1", port), timeout=1.0
                ) as sock:
                    sock.sendall(command.encode() + b"\n")
                    sock.shutdown(socket.SHUT_WR)
                    try:
                        sock.recv(1024)  # the command's result, not needed
                    except OSError:
                        pass
                return True
            except OSError:
                if time.monotonic() >= deadline:
                    return False
                time.sleep(0.3)

    def launch(self, cmd, cwd, note):
        self.procs = [p for p in self.procs if p.poll() is None]  # reap
        try:
            # cwd= changes the working directory but leaves the inherited $PWD behind, 
            # and the PDK xschemrc files resolve netlist_dir from $env(PWD).
            # Keep both in step, like a shell cd does.
            proc = subprocess.Popen(
                cmd,
                cwd=cwd,
                start_new_session=True,
                env={**os.environ, "PWD": str(cwd)},
            )
        except (OSError, ValueError) as exc:
            self.set_status(f"cannot run {' '.join(cmd)}: {exc}")
            return None
        self.procs.append(proc)
        self.set_status(f"{' '.join(cmd)}   ({note})")
        return proc

    def run(self):
        self.win.mainloop()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "root",
        nargs="?",
        default=DEFAULT_ROOT,
        type=Path,
        help="directory to scan (default: $DESIGNS, else the current directory)",
    )
    ap.add_argument(
        "--all",
        action="store_true",
        help="also scan build outputs (runs/, sim_build/, ...), skipped by default",
    )
    ap.add_argument(
        "--prune",
        action="append",
        default=[],
        metavar="NAME",
        help="additional directory name to skip; repeatable",
    )
    ap.add_argument(
        "--max",
        type=int,
        default=Launcher.MAX_BUTTONS,
        metavar="N",
        dest="max_buttons",
        help="most buttons to draw at once, 0 for no limit; past a few hundred "
        f"the X server refuses to allocate more (default: {Launcher.MAX_BUTTONS})",
    )
    ap.add_argument(
        "--refresh",
        type=float,
        default=15.0,
        metavar="SECONDS",
        help="rescan interval, 0 to disable (default: 15)",
    )
    ap.add_argument(
        "--list",
        action="store_true",
        help="print the files that would be shown and exit (no GUI)",
    )
    args = ap.parse_args(argv)

    root = args.root.resolve()
    if not root.is_dir():
        sys.exit(f"not a directory: {root}")
    prune = set() if args.all else PRUNE | set(args.prune)

    if args.list:
        for path in scan(root, prune, set(VIEWERS)):
            print(path.relative_to(root))
        return 0

    try:
        Launcher(
            root,
            prune,
            set(VIEWERS),
            refresh=max(0.0, args.refresh),
            max_buttons=max(0, args.max_buttons),
        ).run()
    except tk.TclError as exc:
        sys.exit(f"cannot open a window ({exc}) -- run this in the VNC/X11 desktop")
    return 0


if __name__ == "__main__":
    sys.exit(main())
