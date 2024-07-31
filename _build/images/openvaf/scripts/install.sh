#!/bin/bash

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${OPENVAF_REPO_URL}" "${OPENVAF_NAME}"
cd "${OPENVAF_NAME}" || exit 1
git checkout "${OPENVAF_REPO_COMMIT}"

# LLVM compile (needs LLVM 15 or 16)

# FIXME patching OpenVAF until PR is merged
patch -p1 << EOF
diff --git a/openvaf/target/build.rs b/openvaf/target/build.rs
index 13db6e5..dada68e 100644
--- a/openvaf/target/build.rs
+++ b/openvaf/target/build.rs
@@ -36,7 +36,7 @@ fn gen_msvcrt_importlib(sh: &Shell, arch: &str, target: &str, check: bool) {
     let ucrt_obj = out_dir.join(format!("ucrt_{arch}.obj"));
     cmd!(
         sh,
-        "clang-cl /c /Zl /GS- /clang:--target={target}-pc-windows-msvc /clang:-o{ucrt_obj} {ucrt_src}"
+        "clang -c -fno-autolink -fno-stack-protector --target={target}-pc-windows-msvc -o{ucrt_obj} {ucrt_src}"
     )
     .run()
     .expect("ucrt compilation succeeds");
EOF

cargo build --release --bin openvaf -j$(nproc)

mkdir -p  "/${TOOLS}/${OPENVAF_NAME}/bin"
cp target/release/openvaf "/${TOOLS}/${OPENVAF_NAME}/bin"
