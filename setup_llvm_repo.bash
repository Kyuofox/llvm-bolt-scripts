#!/bin/bash

git clone -b main https://github.com/llvm/llvm-project.git --depth 1
cd llvm-project
git pull
cd ..
