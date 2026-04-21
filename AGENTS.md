# Agent Notes

## Building sglang + kt-kernel

### Issue: F16C flag not auto-detected during build

The `kt-kernel/install.sh` `detect_cpu_features()` function does not detect F16C, causing build failures when compiling llamafile.

**Working compilation command:**
```bash
source ~/.conda/bin/activate kt-kernel && CFLAGS="-mf16c" CXXFLAGS="-mf16c" CPUINFER_CPU_INSTRUCT=FANCY ./install.sh
```

Alternatively, use `nix develop` first (for nix-managed environment), then activate conda and run the above.
