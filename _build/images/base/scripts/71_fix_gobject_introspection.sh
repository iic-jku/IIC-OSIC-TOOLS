#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# giscanner in Ubuntu 24.04 LTS (gobject-introspection 1.80.1-1) still imports
# distutils.msvccompiler, which no longer exists: on Python 3.12 "distutils"
# comes from setuptools, and setuptools dropped the MSVC compiler modules. Any
# g-ir-scanner run therefore dies with ModuleNotFoundError.
# Fixed upstream in
# https://gitlab.gnome.org/GNOME/gobject-introspection/-/commit/a2139dba59eac283a7f543ed737f038deebddc19
# but not in the noble package (re-checked 2026-08-06), so we patch it here.
# Drop this script once the base image ships a gobject-introspection that
# contains the fix; the patch below then fails to apply and fails the build,
# which is the intended signal.

cat << EOF > /tmp/p1.patch
29d28
< from distutils.msvccompiler import MSVCCompiler
170c169
<             # MSVC9Compiler class, as it does not provide a preprocess()
---
>             # MSVCCompiler class, as it does not provide a preprocess()
463c462
<         return isinstance(self.compiler, MSVCCompiler)
---
>         return self.compiler.compiler_type == "msvc"
489c488
<                     if isinstance(self.compiler, MSVCCompiler):
---
>                     if self.check_is_msvc():
EOF

cat << EOF > /tmp/p2.patch
22c22
< import distutils
---
> from typing import Type
25c25
< from distutils.ccompiler import CCompiler, gen_preprocess_options
---
> from distutils.ccompiler import CCompiler, gen_preprocess_options, new_compiler
31a32,34
> DistutilsMSVCCompiler: Type = type(new_compiler(compiler="msvc"))
> 
> 
36c39
< class MSVCCompiler(distutils.msvccompiler.MSVCCompiler):
---
> class MSVCCompiler(DistutilsMSVCCompiler):
39c42
<         super(distutils.msvccompiler.MSVCCompiler, self).__init__()
---
>         super(DistutilsMSVCCompiler, self).__init__()
43,45d45
<         if os.name == 'nt':
<             if isinstance(self, distutils.msvc9compiler.MSVCCompiler):
<                 self.__version = distutils.msvc9compiler.VERSION
EOF

# apply patch
patch "/usr/lib/$(arch)-linux-gnu/gobject-introspection/giscanner/ccompiler.py" /tmp/p1.patch
patch "/usr/lib/$(arch)-linux-gnu/gobject-introspection/giscanner/msvccompiler.py" /tmp/p2.patch

# clean up (only our own files; /tmp is shared with the other build scripts)
rm -f /tmp/p1.patch /tmp/p2.patch
