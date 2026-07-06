# magic build patches

Patches in this directory are applied (in filename order, via `git apply`) by
`../scripts/install.sh` right after `git checkout ${MAGIC_REPO_COMMIT}` and
before `./configure`.

## 0001-guard-Tk_RestrictEvents-with-TxTkConsole.patch

**Fixes:** SIGSEGV during `extract`/DEF-read when magic runs headless
(`magic -dnull -noconsole`, e.g. the SAK/LibreLane DRC-LVS flow). Crash is
reliably triggered on `aarch64` (Pointer Authentication faults the bad call;
`x86_64` happens to survive it), causing regression test 02 to fail.

**Cause:** upstream commit `d8046fb` (first released in tag `8.3.666`) added
`Tk_RestrictEvents()` calls into `extract/ExtSubtree.c`, `cif/CIFhier.c` and
`lef/defRead.c`, guarded by `if (SigInterruptOnSigIO != -1)`. That guard only
detects true `batchmode`; the `-dnull -noconsole` invocation is not batchmode,
so the guard passes and Tk is called even though `magicdnull` never initializes
the Tk package → the Tk stubs table is NULL → segfault.

**Fix:** guard those call sites with `TxTkConsole` (macro in `utils/main.h`,
`RuntimeFlags & MAIN_TK_CONSOLE`) instead — true only when a Tk console is
actually present. Adds the required `#include "utils/main.h"` to the two files
that lacked it.

**Upstream:** submitted to https://github.com/RTimothyEdwards/magic — remove
this patch once merged and the pinned revision includes the fix.

**Affected magic revisions:** `8.3.666` .. `8.3.670` (current pin).
