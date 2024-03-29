# How does it work

This set of scripts creates a 60% faster LLVM toolchain that can be customly
trained to any project.

The full_workflow.bash will autodetect, if your machine supports LBR or not and choose the correct script which suits to your hardware. 

## How to build

```
git clone https://github.com/ptr1337/llvm-bolt-scripts.git

cd llvm-bolt-scripts

./full_workflow.bash
```

This sequence will give you (hopefully) a faster LLVM toolchain.
Technologies used:

- LLVM Link Time Optimization (LTO)
- Binary Instrumentation and Profile-Guided-Optimization (PGO)
- perf-measurement and branch-sampling and final binary reordering (BOLT)

The goal of the techniques is to utilize the CPU black magic better and layout
the code in a way, that allows faster execution.

Measure performance gains and evaluate if its worth the hazzle :)
You can experiment with technologies, maybe `ThinLTO` is better then `FullLTO`,
....
There are more `stage2-*` scripts available that can be modified to your needs.
For the last bit of performance, train the `stage2-pgo` for your own project
and nothing else! The same goes for `BOLT`.
