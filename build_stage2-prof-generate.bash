#!/bin/bash

BASE_DIR=$(pwd)
CPATH="$(pwd)/stage1/install/bin"

mkdir -p stage2-prof-generate || (echo "Could not create stage2-prof-generate directory"; exit 1)
cd stage2-prof-generate

echo "== Configure Build"
echo "== Build with stage1-tools -- $CPATH"

CC=${CPATH}/clang CXX=${CPATH}/clang++ LD=${CPATH}/lld \
	cmake 	-G Ninja \
	-DBUILD_SHARED_LIBS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$(pwd)/install" \
	-DCLANG_ENABLE_ARCMT=OFF \
	-DCLANG_ENABLE_STATIC_ANALYZER=OFF \
	-DCLANG_PLUGIN_SUPPORT=OFF \
	-DLLVM_ENABLE_BINDINGS=OFF \
	-DLLVM_ENABLE_OCAMLDOC=OFF \
	-DLLVM_INCLUDE_EXAMPLES=OFF \
	-DLLVM_INCLUDE_TESTS=OFF \
	-DLLVM_INCLUDE_DOCS=OFF \
	-DCLANG_VENDOR="Kyuofox-$(date +%Y%m%d)" \
	-DCLANG_REPOSITORY_STRING="GitHub.com/KyuoFoxHuyu" \
	-DLLVM_BUILD_INSTRUMENTED=ON \
	-DLLVM_ENABLE_PROJECTS="clang;lld" \
	-DLLVM_PARALLEL_COMPILE_JOBS="$(nproc)"\
	-DLLVM_PARALLEL_LINK_JOBS="$(nproc)" \
	-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
	-DLLVM_USE_LINKER=lld \
	-DLLVM_USE_NEWPM=ON \
  	../llvm-project/llvm || (echo "Could not configure project!"; exit 1)

echo
echo "== Start Build"
ninja || (echo "Could not build project!"; exit 1)

echo
echo "== Install to $(pwd)/install"
ninja install || (echo "Could not install project!"; exit 1)
