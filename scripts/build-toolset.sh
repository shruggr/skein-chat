#!/usr/bin/env bash
# Rebuild every shell module (the toolset) into out/ from pinned sources plus
# the patches in toolset/patches. Needs rustup with the wasm32-wasip1 target
# (mise use -g rust@latest && rustup target add wasm32-wasip1). findutils'
# `onig` (C) dependency needs a WASI C toolchain; this script fetches
# wasi-sdk itself (pinned below) into .build/ if it isn't there yet; qjs
# (issue #25) is C built with it via cmake + make; python is a pinned upstream
# WASI build checked by SHA-256 (needs curl, unzip, node). Work
# happens in .build/ (git-ignored). See toolset/README.md for what each patch
# does and the toolset survey (issue #13).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
BRUSH_REV=739a15d262005acc1e886da0cadf376c29070875       # reubeno/brush main, 2026-09-25
COREUTILS_REV=dc1efd89948a9ca4c78c3a4b9a6ac891019a8c69   # uutils/coreutils tag 0.12.0
FINDUTILS_REV=28be1fa20c370c43e51f0b2e81ef399f3b3a26db   # uutils/findutils tag 0.10.0
DIFFUTILS_REV=60f65858748d56d7b53c95bbcbaa61185a36c27b   # uutils/diffutils tag v0.5.0
JAQ_REV=c866e70303b5dbc37d83a0b0cbacf10e90af9c8c         # 01mf02/jaq tag v3.1.1
SED_REV=2ce633cb8dd83912d0a01cfdc6fefafdb9f28eaf         # uutils/sed tag 0.2.0
TREE_REV=dfed2820d8d761107b2ddc4bf68b4746c82af302        # peteretelej/tree tag v1.3.0
RAWK_REV=4addaefab9ff35c1e8d00ce348aacee259cf8b26        # quinnjr/rawk tag v0.2.0
QUICKJS_REV=6d46d07d04041b40f4f49eaa7fdebe44c314c699     # quickjs-ng/quickjs tag v0.17.0
PYTHON_VERSION=3.14.7                                     # brettcannon/cpython-wasi-build release v3.14.7
PYTHON_ZIP_SHA256=2e064d3fb8172471d39d741348efa722349c40b96301f69968dff714999c584b  # python-3.14.7-wasi_sdk-24.zip
WASI_SDK_VERSION=34.0
export CARGO_PROFILE_RELEASE_STRIP=true

fetch() { # url dir rev
  if [ ! -d "$2/.git" ]; then git clone -q "$1" "$2"; fi
  git -C "$2" fetch -q origin "$3" 2>/dev/null || git -C "$2" fetch -q --unshallow origin || true
  git -C "$2" checkout -q -f "$3"
  git -C "$2" clean -qfd
}

mkdir -p .build out

# findutils' onig_sys (C) needs a WASI sysroot; the Rust wasm32-wasip1 target
# alone (wasi-libc bundled by rustup) is not enough for compiling C.
if [ ! -x .build/wasi-sdk/bin/clang ]; then
  arch=$(uname -m); case "$arch" in aarch64) arch=arm64 ;; esac
  curl -sL -o .build/wasi-sdk.tar.gz \
    "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION%%.*}/wasi-sdk-${WASI_SDK_VERSION}-${arch}-linux.tar.gz"
  tar -C .build -xzf .build/wasi-sdk.tar.gz
  rm .build/wasi-sdk.tar.gz
  mv ".build/wasi-sdk-${WASI_SDK_VERSION}-${arch}-linux" .build/wasi-sdk
fi
export WASI_SDK_PATH="$ROOT/.build/wasi-sdk"
export CC_wasm32_wasip1="$WASI_SDK_PATH/bin/clang"
export CFLAGS_wasm32_wasip1="--sysroot=$WASI_SDK_PATH/share/wasi-sysroot"

fetch https://github.com/reubeno/brush .build/brush "$BRUSH_REV"
git -C .build/brush apply "$ROOT/toolset/patches/brush.patch"
rustup target add wasm32-wasip1 --toolchain "$(cd .build/brush && rustup show active-toolchain | cut -d' ' -f1)" >/dev/null
(cd .build/brush && cargo build --release --target wasm32-wasip1 -p brush-shell --no-default-features --features minimal)
cp .build/brush/target/wasm32-wasip1/release/brush.wasm out/brush.wasm

fetch https://github.com/uutils/coreutils .build/coreutils "$COREUTILS_REV"
git -C .build/coreutils apply "$ROOT/toolset/patches/coreutils.patch"
(cd .build/coreutils && cargo build --release --target wasm32-wasip1 --no-default-features --features feat_wasm)
cp .build/coreutils/target/wasm32-wasip1/release/coreutils.wasm out/coreutils.wasm

# --- the toolset (issue #13): search/edit/structured-data beyond coreutils ---

fetch https://github.com/uutils/findutils .build/findutils "$FINDUTILS_REV"
git -C .build/findutils apply "$ROOT/toolset/patches/findutils.patch"
(cd .build/findutils && cargo build --release --target wasm32-wasip1 --bin find --bin xargs)
cp .build/findutils/target/wasm32-wasip1/release/find.wasm out/find.wasm
cp .build/findutils/target/wasm32-wasip1/release/xargs.wasm out/xargs.wasm

fetch https://github.com/uutils/diffutils .build/diffutils "$DIFFUTILS_REV"
git -C .build/diffutils apply "$ROOT/toolset/patches/diffutils.patch"
(cd .build/diffutils && cargo build --release --target wasm32-wasip1)
# One multicall binary (like coreutils' own), registered under both names.
cp .build/diffutils/target/wasm32-wasip1/release/diffutils.wasm out/diff.wasm
cp .build/diffutils/target/wasm32-wasip1/release/diffutils.wasm out/cmp.wasm

fetch https://github.com/01mf02/jaq .build/jaq "$JAQ_REV"
git -C .build/jaq apply "$ROOT/toolset/patches/jaq.patch"
(cd .build/jaq && cargo build --release --target wasm32-wasip1 -p jaq --no-default-features)
cp .build/jaq/target/wasm32-wasip1/release/jaq.wasm out/jq.wasm

fetch https://github.com/uutils/sed .build/sed-cli "$SED_REV"
git -C .build/sed-cli apply "$ROOT/toolset/patches/sed.patch"
(cd .build/sed-cli && cargo build --release --target wasm32-wasip1)
cp .build/sed-cli/target/wasm32-wasip1/release/sed.wasm out/sed.wasm

fetch https://github.com/peteretelej/tree .build/tree-cli "$TREE_REV"
(cd .build/tree-cli && cargo build --release --target wasm32-wasip1)
cp .build/tree-cli/target/wasm32-wasip1/release/tree.wasm out/tree.wasm

fetch https://github.com/quinnjr/rawk .build/rawk "$RAWK_REV"
(cd .build/rawk && cargo build --release --target wasm32-wasip1)
cp .build/rawk/target/wasm32-wasip1/release/awk-rs.wasm out/awk.wasm

# which, grep: first-party (no upstream Rust CLI exists for either — see
# toolset/README.md), built straight from toolset/tools/.
(cd toolset/tools/which && cargo build --release --target wasm32-wasip1)
cp toolset/tools/which/target/wasm32-wasip1/release/which.wasm out/which.wasm
(cd toolset/tools/grep && cargo build --release --target wasm32-wasip1)
cp toolset/tools/grep/target/wasm32-wasip1/release/grep.wasm out/grep.wasm

# git (issue #2): real git in C, for wasm32-wasip1 with wasi-sdk's clang, from
# the release tarballs (checked by sha256), + patches/git.patch and the WASI
# compat layer in toolset/git/ (config.mak, wasi-compat.h, compat.c, include/).
# Built fresh each time in .build/git-$GIT_VERSION so nothing stale leaks in.
GIT_VERSION=2.55.0
GIT_SHA256=457fdb04dc8728e007d4688695e6912e6f680727920f2a40bf11eacc17505357
ZLIB_VERSION=1.3.2
ZLIB_SHA256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
tarball() { # url file sha256
  if [ ! -f "$2" ] || ! echo "$3  $2" | sha256sum -c --quiet - 2>/dev/null; then curl -sL -o "$2" "$1"; fi
  echo "$3  $2" | sha256sum -c --quiet -
}
tarball "https://www.kernel.org/pub/software/scm/git/git-$GIT_VERSION.tar.xz" .build/git-$GIT_VERSION.tar.xz "$GIT_SHA256"
tarball "https://github.com/madler/zlib/releases/download/v$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz" .build/zlib-$ZLIB_VERSION.tar.gz "$ZLIB_SHA256"
WASI_CC="$WASI_SDK_PATH/bin/clang --target=wasm32-wasip1 --sysroot=$WASI_SDK_PATH/share/wasi-sysroot"
rm -rf .build/zlib-$ZLIB_VERSION .build/zlib-wasi .build/git-$GIT_VERSION
tar -C .build -xzf .build/zlib-$ZLIB_VERSION.tar.gz
(cd .build/zlib-$ZLIB_VERSION && CC="$WASI_CC" AR="$WASI_SDK_PATH/bin/llvm-ar" RANLIB="$WASI_SDK_PATH/bin/llvm-ranlib" CFLAGS=-O2 \
  ./configure --static --prefix="$ROOT/.build/zlib-wasi" >/dev/null && make -j"$(nproc)" libz.a >/dev/null && make install >/dev/null)
tar -C .build -xJf .build/git-$GIT_VERSION.tar.xz
(cd .build/git-$GIT_VERSION && patch -s -p1 < "$ROOT/toolset/patches/git.patch" && cp "$ROOT/toolset/git/config.mak" config.mak)
$WASI_CC -O2 -D_WASI_EMULATED_SIGNAL -I"$ROOT/toolset/git/include" -c toolset/git/compat.c -o .build/git-$GIT_VERSION/skein-compat.o
# uname_*: no host platform's section of config.mak.uname applies.
make -C .build/git-$GIT_VERSION -j"$(nproc)" uname_S=WASI uname_M=wasm32 uname_O=WASI uname_R=1 uname_V=1 \
  SKEIN_WASI_SDK="$WASI_SDK_PATH" SKEIN_ZLIB="$ROOT/.build/zlib-wasi" SKEIN_COMPAT="$ROOT/toolset/git" \
  SKEIN_COMPAT_OBJ="$ROOT/.build/git-$GIT_VERSION/skein-compat.o" git >/dev/null
cp .build/git-$GIT_VERSION/git out/git.wasm

# --- script runtimes (issue #25): JavaScript and Python ---

# qjs: QuickJS-ng with wasi-sdk (C), + patches/quickjs.patch, which compiles
# in toolset/tools/qjs (console methods; the `node` shim when run as `node`).
fetch https://github.com/quickjs-ng/quickjs .build/quickjs "$QUICKJS_REV"
git -C .build/quickjs apply "$ROOT/toolset/patches/quickjs.patch"
node toolset/tools/qjs/gen-prelude.mjs .build/quickjs/skein-prelude.h
cmake -S .build/quickjs -B .build/quickjs/build-wasi \
  -DCMAKE_TOOLCHAIN_FILE="$WASI_SDK_PATH/share/cmake/wasi-sdk-p1.cmake" -DWASI_SDK_PREFIX="$WASI_SDK_PATH" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-DSKEIN_PRELUDE >/dev/null
make -s -C .build/quickjs/build-wasi -j"$(nproc)" qjs_exe
"$WASI_SDK_PATH/bin/llvm-strip" -o out/qjs.wasm .build/quickjs/build-wasi/qjs

# python: the CPython WASI build published by a CPython core dev
# (brettcannon/cpython-wasi-build, built with wasi-sdk 24), checked against
# its pinned SHA-256; stripped of its debug sections; the stdlib packed into
# a stored zip (the build has no zlib) that the shell mounts read-only.
if ! echo "$PYTHON_ZIP_SHA256  .build/python-wasi.zip" | sha256sum -c --status 2>/dev/null; then
  curl -sSL -o .build/python-wasi.zip \
    "https://github.com/brettcannon/cpython-wasi-build/releases/download/v${PYTHON_VERSION}/python-${PYTHON_VERSION}-wasi_sdk-24.zip"
  echo "$PYTHON_ZIP_SHA256  .build/python-wasi.zip" | sha256sum -c --quiet
fi
rm -rf .build/python-wasi
mkdir -p .build/python-wasi
(cd .build/python-wasi && unzip -q ../python-wasi.zip)
"$WASI_SDK_PATH/bin/llvm-strip" -o out/python.wasm .build/python-wasi/python.wasm
node toolset/tools/python/zip-stdlib.mjs ".build/python-wasi/lib/python${PYTHON_VERSION%.*}" "out/python$(echo "${PYTHON_VERSION%.*}" | tr -d .).zip"

sha256sum out/*.wasm out/*.zip
