# Surfer Crash on macOS — Investigation Report

Date: 2026-07-23
Image: `hpretl/iic-osic-tools:latest` (2026.06), Surfer v0.7.0, Mesa 25.2.8, aarch64
Host: macOS (Apple Silicon), Docker Desktop, XQuartz 2.8.x (`-listen tcp +iglx`)

## Symptom

Starting `surfer` in X11 mode (`start_x.sh`, display forwarded to XQuartz via
socat/TCP) aborts immediately:

```
thread 'main' (ThreadId(1)) panicked at surfer/src/main.rs:235:88
  called `Result::unwrap()` on an `Err` value:
  Glutin(Error { raw_code: Some(170), raw_os_message: Some("GLXBadFBConfig"), kind: BadConfig })
```

The `alias surfer='LIBGL_ALWAYS_INDIRECT=0 surfer'` workaround in the base
`.bashrc` has no effect (verified), and neither does enabling `+iglx` in
XQuartz. In VNC mode (`start_vnc.sh`) Surfer works.

## Root Causes

Two independent bugs stack up over the container → TCP → XQuartz connection.

### 1. Crash: eframe commits to GLX, which is unusable against XQuartz

Surfer v0.7.0 builds eframe 0.34.1 with only the `glow` (OpenGL) feature
(no wgpu). eframe hardcodes `glutin_winit::ApiPreference::FallbackEgl`
([glow_integration.rs:996 in egui 0.34.1](https://github.com/emilk/egui/blob/0.34.1/crates/eframe/src/native/glow_integration.rs)):
GLX is tried first, and EGL is only used if GLX *display creation* fails.

- XQuartz advertises the GLX extension, so glutin commits to GLX.
- Mesa cannot create a client-side software (drisw) screen against XQuartz.
  `LIBGL_DEBUG=verbose` shows:
  `No matching fbConfigs or visuals found` → `glx: failed to create drisw screen`
  (Mesa cannot match its swrast configs to XQuartz's GLX fbconfigs).
- Mesa silently falls back to **indirect GLX**, which is limited to
  OpenGL 1.4. glutin's request for a ≥3.x core context then fails with
  `GLXBadFBConfig` and Surfer panics. `LIBGL_ALWAYS_INDIRECT` is irrelevant
  to this failure path, which is why the old alias never helped.

Meanwhile, **EGL on the same X connection works perfectly**: `eglinfo -B -p x11`
reports llvmpipe with OpenGL 4.5 core / ES 3.2 (client-side software
rendering, presented to the X server as images).

### 2. Blank window: Mesa's MIT-SHM detection is wrong for XQuartz over TCP

With EGL forced, Surfer starts and maps a window, but the window stays blank
and stderr floods with:

```
MESA: error: Failed to attach to x11 shm
```

Mesa's `check_xshm()` (`src/egl/drivers/dri2/platform_x11.c`) decides SHM is
usable by sending a bogus `shm_detach(0)` and treating a `BadValue` response
as "we are a local client". XQuartz implements MIT-SHM, so the probe passes —
but a SysV SHM segment created inside a Linux container can never be attached
by an X server running on the macOS host. Every frame's `shm_attach` fails,
there is no per-frame fallback, and no image ever reaches the server
(measured: ~1.2 MB total X traffic in 12 s, i.e. no frames; 578 SHM errors).
Mesa offers no environment variable to disable this path.

However, if `shmget()` itself fails, Mesa's software winsys
(`dri_sw_winsys.c`) cleanly falls back to malloc'd buffers presented via
core-protocol `PutImage`, which works over TCP.

## Fix (applied)

A wrapper `${TOOLS}/bin/surfer` (installed by `install_links.sh`, same
pattern as the AppCSXCAD wrapper) plus two build-time artifacts
(built in `_build/images/surfer/scripts/install.sh`):

1. **Force EGL** — `${TOOLS}/surfer/lib/noglx/` contains empty
   `libGL.so.1`/`libGL.so` stub files and is prepended to `LD_LIBRARY_PATH`.
   glutin's `dlopen("libGL.so.1")` fails, GLX display creation fails, and
   eframe falls back to the working EGL path. Applied unconditionally: EGL
   is equivalent to GLX on all supported configurations (llvmpipe in
   software setups, DRI3 hardware acceleration where `/dev/dri` is passed),
   and only the Surfer process is affected.

2. **Disable MIT-SHM on TCP displays** — `${TOOLS}/surfer/lib/libnoshm.so`
   (an `LD_PRELOAD` shim overriding `shmget()` to return `-1`/`ENOSYS`) is
   applied only when `$DISPLAY` does not match `:*` or `unix:*`. Local
   displays (VNC mode) keep genuine SHM presentation for speed.

Additional cleanup: the ineffective `surfer` alias was removed from the base
`.bashrc`; `KNOWN_ISSUES.md` and `RELEASE_NOTES.md` were updated.

## Verification

All tests run in unmodified `hpretl/iic-osic-tools:latest` containers with the
wrapper and shims installed exactly as the build scripts produce them:

| Scenario | Before | After |
|---|---|---|
| X11 mode, XQuartz over TCP | `GLXBadFBConfig` panic | Window renders full UI (screenshot-verified); ~170 MB/s X traffic confirms frames delivered; 0 SHM errors |
| X11 mode + only EGL forced (no SHM shim) | Blank window, 578 SHM errors, no frame traffic | n/a (intermediate result motivating part 2) |
| VNC mode, local Xvnc | worked | Still works, full UI renders; `LD_PRELOAD` correctly not applied |

Rendering is software (llvmpipe) and X11 mode pushes uncompressed ~8 MB
frames over the X connection; VNC mode remains the smoother option for
Surfer, which is now noted in `KNOWN_ISSUES.md`.

## Upstream Issues Worth Filing

- **eframe/egui**: no way to prefer EGL over GLX at runtime; the code
  comment at the `FallbackEgl` line already suggests exposing an env var or
  `NativeOptions` field. A `GLXBadFBConfig` at context-creation time could
  also trigger an EGL retry instead of a panic.
- **Mesa**: `check_xshm()`'s `BadValue`-means-local heuristic is wrong for
  XQuartz reached over TCP (and any non-Linux X server implementing
  MIT-SHM); `swrastPutImageShm` could fall back to `PutImage` when
  `shm_attach` fails instead of dropping the frame.
- **Surfer**: could ship the eframe `wgpu` backend (wgpu's GL path uses EGL
  directly and would avoid bug 1, though not bug 2).

## Files Changed

- `_build/images/surfer/scripts/install.sh` — build `libnoshm.so` and the
  `noglx` libGL stubs into `${TOOLS}/surfer/lib/`.
- `_build/images/iic-osic-tools/skel/headless/scripts/install_links.sh` —
  install the `surfer` wrapper instead of the plain symlink.
- `_build/images/base/skel/headless/.bashrc` — remove obsolete alias.
- `KNOWN_ISSUES.md` — rewrite "Surfer Crashing" section.
- `RELEASE_NOTES.md` — add 2026.07 fix entry.
