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
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          python3
          uv
          gcc
          clang
          ghidra
        ];

        env = {
          LD_LIBRARY_PATH = lib.makeLibraryPath (pkgs.pythonManylinuxPackages.manylinux1 ++ [ pkgs.zstd ]);
          HSA_OVERRIDE_GFX_VERSION = "10.3.0";
          CUDA_VISIBLE_DEVICES = 0;
        };

        shellHook = ''
          unset PYTHONPATH
          uv sync
          . .venv/bin/activate
        '';
      };
    };
}
