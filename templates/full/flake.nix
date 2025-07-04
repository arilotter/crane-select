{
  description = "Full example of selective Cargo workspace with advanced features";

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

          # Example of passing crane parameters
          buildInputs = with pkgs; [ openssl ];
          nativeBuildInputs = with pkgs; [ pkg-config ];
        };
      in
      {
        packages = workspace.crates // {
          # Combined package with all crates
          default = workspace.crates.app;

          # All crates combined
          all = pkgs.symlinkJoin {
            name = "workspace-all";
            paths = builtins.attrValues workspace.crates;
          };

          # Example of building a crate with custom parameters
          crate-a-static = workspace.buildCrate "crate-a" {
            # Custom build parameters for this specific crate
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
