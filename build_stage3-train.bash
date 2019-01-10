#!/bin/bash

BASE_DIR=$(pwd)
CPATH="$(pwd)/stage2-prof-generate/install/bin"

mkdir -p stage3-train || (echo "Could not create stage3-train directory"; exit 1)
cd stage3-train

echo "== Configure Build"
echo "== Build with stage2-prof-generate-tools -- $CPATH"
# AArch64 seems to be necessary for llvm-bolt (facebook thingie)
CC=${CPATH}/clang CXX=${CPATH}/clang++ LD=${CPATH}/lld \
cmake 	-G Ninja \
	-DBUILD_SHARED_LIBS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$(pwd)/install" \
	-DCLANG_ENABLE_ARCMT=OFF \
	-DCLANG_ENABLE_STATIC_ANALYZER=OFF \
	-DCLANG_VENDOR="LogMeIn" \
	-DLLVM_ENABLE_LLD=ON \
	-DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
	-DLLVM_PARALLEL_COMPILE_JOBS="$(nproc)"\
	-DLLVM_PARALLEL_LINK_JOBS="$(nproc)" \
	-DLLVM_POLLY_BUILD=ON \
	-DLLVM_TARGETS_TO_BUILD="all" \
	-DLLVM_TOOL_CLANG_BUILD=ON \
	-DLLVM_TOOL_CLANG_TOOLS_EXTRA_BUILD=OFF \
	-DLLVM_TOOL_COMPILER_RT_BUILD=ON \
	-DLLVM_TOOL_LLD_BUILD=ON \
	../../llvm-project/llvm || (echo "Could not configure project!"; exit 1)

echo
echo "== Start Build"
ninja || (echo "Could not build project for training!"; exit 1)

echo
echo "== Merge Profile data"
cd profiles/
${BASE_DIR}/stage1/install/bin/llvm-profdata merge -output=clang.prof *.profraw