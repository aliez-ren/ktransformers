{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          function (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          })
        );
    in
    {
      formatter = forAllSystems (pkgs: pkgs.alejandra);
      devShells = forAllSystems (pkgs: {
        default =
          let
            cudaPkgs = pkgs.cudaPackages;

            # Unified CUDA_HOME for kt-kernel build.
            # Nix CUDA packages split outputs (out, dev, include, lib, …);
            # symlinkJoin only follows the default "out" output, so we must
            # list the specific sub-outputs we need.
            cudaHome = pkgs.symlinkJoin {
              name = "cuda-home";
              paths =
                (with cudaPkgs; [
                  # ── compiler & core runtime ──
                  cuda_nvcc          # nvcc compiler
                  cuda_cudart        # cuda_runtime.h, libcudart
                  cuda_cccl          # thrust / cub headers

                  # ── cuBLAS (used by kt-kernel cpu_backend/vendors/cuda.h) ──
                  libcublas.include  # cublas_v2.h, cublasLt.h
                  libcublas.lib      # libcublas.so
                  libcublas.stubs

                  # ── cuRAND (required by flashinfer sampling JIT kernels) ──
                  libcurand.include  # curand.h
                  libcurand.lib      # libcurand.so
                ]);
            };
          in
          pkgs.mkShell {
            packages = with pkgs; [
              cmake
              clang-tools
              cpptrace
              pkg-config
              hwloc
              numactl
              conda
            ];
            CFLAGS = "-mf16c";
            CXXFLAGS = "-mf16c";
            CPUINFER_CPU_INSTRUCT = "FANCY";
            CPUINFER_CUDA_ARCHS = "80;86;89;90;120";
            TORCH_CUDA_ARCH_LIST = "8.0;8.6;8.9;9.0;12.0";

            # nvcc (a Nix wrapper) hardcodes include paths to the cuda_nvcc
            # store path, which does NOT contain cuda_runtime.h (that lives
            # in cuda_cudart).  The symlink-join exposes it under
            # $cudaHome/include, so we must add that to the standard
            # C/C++ include search paths so that the host compiler nvcc
            # invokes can find it.
            C_INCLUDE_PATH = "${cudaHome}/include";
            CPLUS_INCLUDE_PATH = "${cudaHome}/include";

            LD_LIBRARY_PATH = lib.concatStringsSep ":" [
              "/run/opengl-driver/lib"
              "${cudaHome}/lib"
              (lib.makeLibraryPath [
                pkgs.hwloc
                pkgs.numactl
              ])
            ];
            LIBRARY_PATH = lib.concatStringsSep ":" [
              "/run/opengl-driver/lib"
              "${cudaHome}/lib"
              (lib.makeLibraryPath [
                pkgs.hwloc
                pkgs.numactl
              ])
            ];
            shellHook = ''
              CONDA_ACTIVATE="$HOME/.conda/bin/activate"
              CONDA_ENV_NAME="''${KTRANSFORMERS_CONDA_ENV:-kt-kernel}"

              if [ ! -f "$CONDA_ACTIVATE" ]; then
                echo "ktransformers devShell: conda activate script not found at $CONDA_ACTIVATE" >&2
                return 1
              fi

              . "$CONDA_ACTIVATE" "$CONDA_ENV_NAME"

              export CUDA_HOME="${cudaHome}"
              export PATH="${cudaHome}/bin''${PATH:+:$PATH}"

              # Triton hardcodes /sbin/ldconfig to find libcuda.so.1; that path
              # doesn't exist in Nix.  Setting TRITON_LIBCUDA_PATH bypasses the
              # ldconfig call entirely.
              export TRITON_LIBCUDA_PATH="/run/opengl-driver/lib"

              # PyTorch 2.9.1 + CuDNN < 9.15 has a known Conv3d bug that SGLang
              # detects and rejects at startup.  The vision tower doesn't use
              # Conv3d during language-only inference, so the check can be skipped.
              export SGLANG_DISABLE_CUDNN_CHECK=1
            '';
          };
      });
    };
}
