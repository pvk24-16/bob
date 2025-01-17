{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gitignore.url = "github:hercules-ci/gitignore.nix";
    gitignore.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, ... }:
    inputs.flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import inputs.nixpkgs {inherit system;};
        zig = pkgs.zig_0_13;
        inherit (inputs.gitignore.lib) gitignoreSource;
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ zig_0_13 zls ];
        };
      }
    );
}
