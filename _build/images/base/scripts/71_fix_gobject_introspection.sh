#!/bin/bash

set -e

# FIXME there is a nasty bug in 24.04 LTS gobject-introspection
# see https://gitlab.gnome.org/GNOME/gobject-introspection/-/commit/a2139dba59eac283a7f543ed737f038deebddc19
# until this is available upstream, we patch it here

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

# clean up
rm -f /tmp/p1.patch
rm -f /tmp/p2.patch
