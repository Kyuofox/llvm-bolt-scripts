#!/bin/bash

echo "== Choosing latest release (7.x-branch)"
cd llvm-project

git checkout release/13.x
cd $SCRIPT_PATH