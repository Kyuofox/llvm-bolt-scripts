#!/bin/bash

jobs="$(echo $(( $(nproc) * 3/4 )) | cut -d '.' -f1)"

export TOPLEV=~/llvm-bolt/

mkdir ${TOPLEV}
cd ${TOPLEV}

echo "Cloning LLVM"

git clone https://github.com/llvm/llvm-project.git
cd llvm-project
git pull
cd ..

echo "Building Stage 1 Compiler"

mkdir ${TOPLEV}/stage1
cd ${TOPLEV}/stage1

cmake -G Ninja ${TOPLEV}/llvm-project/llvm -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DCMAKE_ASM_COMPILER=gcc \
      -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt;bolt" \
      -DCOMPILER_RT_BUILD_SANITIZERS=OFF -DCOMPILER_RT_BUILD_XRAY=OFF \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DCLANG_VENDOR="Kyuofox-$(date +%Y%m%d)" \
	  -DCLANG_REPOSITORY_STRING="GitHub.com/KyuoFoxHuyu" \
      -DCMAKE_INSTALL_PREFIX=${TOPLEV}/stage1/install
      
ninja install

echo "Building Stage 2 Compiler with Instrumentation"

mkdir ${TOPLEV}/stage2-prof-gen
cd ${TOPLEV}/stage2-prof-gen
CPATH=${TOPLEV}/stage1/install/bin/

cmake -G Ninja ${TOPLEV}/llvm-project/llvm -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$CPATH/clang -DCMAKE_CXX_COMPILER=$CPATH/clang++ \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
	-DLLVM_PARALLEL_LINK_JOBS="$(jobs)" \
    -DLLVM_USE_LINKER=lld -DLLVM_BUILD_INSTRUMENTED=ON \
    -DCLANG_VENDOR="Kyuofox-$(date +%Y%m%d)" \
	-DCLANG_REPOSITORY_STRING="GitHub.com/KyuoFoxHuyu" \
    -DCMAKE_INSTALL_PREFIX=${TOPLEV}/stage2-prof-gen/install
ninja install


echo "Generating Profile for PGO"

mkdir ${TOPLEV}/stage3-train
cd ${TOPLEV}/stage3-train
CPATH=${TOPLEV}/stage2-prof-gen/install/bin

cmake -G Ninja ${TOPLEV}/llvm-project/llvm -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$CPATH/clang -DCMAKE_CXX_COMPILER=$CPATH/clang++ \
    -DLLVM_ENABLE_PROJECTS="clang" \
	-DLLVM_PARALLEL_LINK_JOBS="$(jobs)" \
	-DCLANG_VENDOR="Kyuofox-$(date +%Y%m%d)" \
	-DCLANG_REPOSITORY_STRING="GitHub.com/KyuoFoxHuyu" \
    -DLLVM_USE_LINKER=lld -DCMAKE_INSTALL_PREFIX=${TOPLEV}/stage3-train/install
ninja clang


echo "Merging PGO-Profiles"

cd ${TOPLEV}/stage2-prof-gen/profiles
${TOPLEV}/stage1/install/bin/llvm-profdata merge -output=clang.profdata *

echo "Building Clang with PGO and LTO"

mkdir ${TOPLEV}/stage2-prof-use-lto
cd ${TOPLEV}/stage2-prof-use-lto
CPATH=${TOPLEV}/stage1/install/bin/

export LDFLAGS="-Wl,-q"

cmake -G Ninja ${TOPLEV}/llvm-project/llvm -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$CPATH/clang -DCMAKE_CXX_COMPILER=$CPATH/clang++ \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_ENABLE_LTO=Thin \
    -DCLANG_VENDOR="Kyuofox-$(date +%Y%m%d)" \
	-DCLANG_REPOSITORY_STRING="GitHub.com/KyuoFoxHuyu" \
	-DLLVM_PARALLEL_LINK_JOBS="$(jobs)" \
    -DLLVM_PROFDATA_FILE=${TOPLEV}/stage2-prof-gen/profiles/clang.profdata \
    -DLLVM_USE_LINKER=lld \
    -DCMAKE_INSTALL_PREFIX=${TOPLEV}/stage2-prof-use-lto/install
ninja install


echo "Recording Profile with perf record for bolt"

mkdir ${TOPLEV}/stage3
cd ${TOPLEV}/stage3
CPATH=${TOPLEV}/stage2-prof-use-lto/install/bin/

cmake -G Ninja ${TOPLEV}/llvm-project/llvm -DLLVM_TARGETS_TO_BUILD="ARM;AArch64;X86" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=$CPATH/clang -DCMAKE_CXX_COMPILER=$CPATH/clang++ \
    -DCLANG_VENDOR="Kyuofox-$(date +%Y%m%d)" \
	-DCLANG_REPOSITORY_STRING="GitHub.com/KyuoFoxHuyu" \
	-DLLVM_ENABLE_PROJECTS="clang;lld;polly;bolt" \
	-DLLVM_ENABLE_LTO=Thin \
    -DLLVM_USE_LINKER=lld -DCMAKE_INSTALL_PREFIX=${TOPLEV}/stage3/install

perf record -e cycles:u ,u -- ninja

echo "Converting profile to a more aggreated form suitable to be consumed by BOLT"

export ${TOPLEV}/stage1/install/bin/:${PATH}

perf2bolt $CPATH/clang-15 -p perf.data -o clang-15.fdata -w clang-15.yaml

echo "Optimizing Clang with the generated profile"

llvm-bolt $CPATH/clang-15 -o $CPATH/clang-15.bolt -b clang-15.yaml \
    -reorder-blocks=cache+ -reorder-functions=hfsort+ -split-functions=3 \
    -split-all-cold -dyno-stats -icf=1 -use-gnu-stack
    
echo "Mooving orginal binary and linking bolted one"

mv $CPATH/clang-15 $CPATH/clang-15.org

ln -fs $CPATH/clang-15.bolt $CPATH/clang-15


## Optional measuring performance difference between the bolted binary and the LTO+PGO builded binary

# ln -fs $CPATH/clang-15.org $CPATH/clang-15
# ninja clean && time ninja clang -j$(nproc)

# ln -fs $CPATH/clang-15.bolt $CPATH/clang-15
# ninja clean && time ninja clang -j$(nproc)
