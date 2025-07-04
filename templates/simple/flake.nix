{
  description = "Simple selective Cargo workspace";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    crane-select.url = "github:arilotter/crane-select";
  };

  outputs =
    {
      nixpkgs,
      crane,
      flake-utils,
      crane-select,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = crane.mkLib pkgs;

        workspace = crane-select.lib.${system}.mkWorkspace {
          src = ./.;
        };
      in
      {
        packages = workspace.crates // {
          default = workspace.crates.app or (builtins.head (builtins.attrValues workspace.crates));
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cargo
            rustc
            rust-analyzer
          ];
        };
      }
    );
}
