{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs =
    { nixpkgs, ... }:
    let
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
          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
          ];
          buildInputs = with pkgs; [
            hwloc
            numactl
          ];
          packages = with pkgs; [
            conda
          ];
          shellHook = ''
            append_flag() {
              local var_name="$1"
              local flag="$2"
              local current_value
              eval "current_value=\''${$var_name-}"

              case " $current_value " in
                *" $flag "*) ;;
                *) export "$var_name=''${current_value:+$current_value }$flag" ;;
              esac
            }

            prepend_path_once() {
              local var_name="$1"
              local path_entry="$2"
              local current_value
              eval "current_value=\''${$var_name-}"

              case ":$current_value:" in
                *":$path_entry:"*) ;;
                *) export "$var_name=$path_entry''${current_value:+:$current_value}" ;;
              esac
            }

            CONDA_ACTIVATE="$HOME/.conda/bin/activate"
            CONDA_ENV_NAME="''${KTRANSFORMERS_CONDA_ENV:-kt-kernel}"
            NVIDIA_DRIVER_LIB_DIR="/run/opengl-driver/lib"

            if [ ! -f "$CONDA_ACTIVATE" ]; then
              echo "ktransformers devShell: conda activate script not found at $CONDA_ACTIVATE" >&2
              return 1
            fi

            . "$CONDA_ACTIVATE" "$CONDA_ENV_NAME"

            append_flag CFLAGS -mf16c
            append_flag CXXFLAGS -mf16c
            export CPUINFER_CPU_INSTRUCT="''${CPUINFER_CPU_INSTRUCT:-FANCY}"

            if [ -d "$NVIDIA_DRIVER_LIB_DIR" ]; then
              prepend_path_once LD_LIBRARY_PATH "$NVIDIA_DRIVER_LIB_DIR"
              prepend_path_once LIBRARY_PATH "$NVIDIA_DRIVER_LIB_DIR"
            fi

            for cuda_home_candidate in /usr/local/cuda /usr/local/cuda-* "''${CONDA_PREFIX:-}"; do
              [ -n "$cuda_home_candidate" ] || continue
              if [ -x "$cuda_home_candidate/bin/nvcc" ]; then
                export CUDA_HOME="$cuda_home_candidate"
                prepend_path_once PATH "$CUDA_HOME/bin"
                break
              fi
            done
          '';
        };
      });
    };
}
