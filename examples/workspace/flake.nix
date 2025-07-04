{
  description = "Example workspace using crane-select library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    crane-select.url = "path:../..";
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
          default = workspace.crates.app;

          # All crates combined
          all = pkgs.symlinkJoin {
            name = "workspace-all";
            paths = builtins.attrValues workspace.crates;
          };

          # Example of building a crate with custom parameters
          crate-a-static = workspace.buildCrate "crate-a" {
            cargoExtraArgs = "--features=static";
          };

          # Debug utilities
          debug-overview = pkgs.writeTextFile {
            name = "debug-overview";
            text = builtins.toJSON {
              members = map (m: m.name) workspace.utils.workspaceMembers;
              dependencyGraph = builtins.listToAttrs (
                map (member: {
                  name = member.name;
                  value = workspace.utils.getDependencies member.name;
                }) workspace.utils.workspaceMembers
              );
            };
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cargo
            rustc
            rust-analyzer
            clippy
            rustfmt
          ];
        };

        # Checks for CI
        checks = workspace.crates;

        # Apps
        apps = {
          default = flake-utils.lib.mkApp {
            drv = workspace.crates.app;
          };
        };
      }
    );
}
