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
          system: function nixpkgs.legacyPackages.${system}
        );
    in
    {
      formatter = forAllSystems (pkgs: pkgs.alejandra);
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
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

            for cuda_home_candidate in /usr/local/cuda /usr/local/cuda-* "''${CONDA_PREFIX:-}"; do
              [ -n "$cuda_home_candidate" ] || continue
              if [ -x "$cuda_home_candidate/bin/nvcc" ]; then
                export CUDA_HOME="$cuda_home_candidate"
                case ":$PATH:" in
                  *":$CUDA_HOME/bin:"*) ;;
                  *) export PATH="$CUDA_HOME/bin:$PATH" ;;
                esac
                break
              fi
            done
          '';
        };
      });
    };
}
