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
            cudaHome = pkgs.symlinkJoin {
              name = "cuda-home";
              paths = with pkgs.cudaPackages; [
                cuda_nvcc
                cuda_cudart
                cuda_cccl
              ];
            };
          in
          pkgs.mkShell {
            packages = with pkgs; [
              cmake
              pkg-config
              hwloc
              numactl
              conda
            ];
            CFLAGS = "-mf16c";
            CXXFLAGS = "-mf16c";
            CPUINFER_CPU_INSTRUCT = "FANCY";
            LD_LIBRARY_PATH = lib.concatStringsSep ":" [
              "/run/opengl-driver/lib"
              (lib.makeLibraryPath [
                pkgs.hwloc
                pkgs.numactl
              ])
            ];
            LIBRARY_PATH = lib.concatStringsSep ":" [
              "/run/opengl-driver/lib"
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
            '';
          };
      });
    };
}
