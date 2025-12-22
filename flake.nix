{
  description = "RevBench flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      rocmtoolkit_joined = pkgs.symlinkJoin {
        name = "rocm-merged";

        paths = with pkgs.rocmPackages; [
          rocm-core
          clr
          rccl
          miopen
          aotriton
          rocrand
          rocblas
          rocsparse
          hipsparse
          rocthrust
          rocprim
          hipcub
          roctracer
          rocfft
          rocsolver
          hipfft
          hiprand
          hipsolver
          hipblas-common
          hipblas
          hipblaslt
          rocminfo
          rocm-comgr
          rocm-device-libs
          rocm-runtime
          rocm-smi
          clr.icd
          composable_kernel
          hipify
        ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          python3
          uv
          gcc
          clang
          ghidra
          cmake
          pkg-config
          rocmtoolkit_joined
        ];

        env = {
          LD_LIBRARY_PATH = lib.makeLibraryPath (pkgs.pythonManylinuxPackages.manylinux1 ++ [ pkgs.zstd ]);
          HSA_OVERRIDE_GFX_VERSION = "10.3.0";
          CUDA_VISIBLE_DEVICES = 0;
          ROCM_PATH = rocmtoolkit_joined;
          ROCM_SOURCE_DIR = rocmtoolkit_joined;
          PYTORCH_ROCM_ARCH = "gfx1030";
          CMAKE_CXX_FLAGS = "-I${rocmtoolkit_joined}/include";
        };

        shellHook = ''
          unset PYTHONPATH
          uv sync
          . .venv/bin/activate
        '';
      };
    };
}
