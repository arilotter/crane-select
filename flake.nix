{
  description = "Selective Cargo Workspace Builder for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    nix-std.url = "github:chessai/nix-std";
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    nix-std,
  }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        craneLib = crane.mkLib pkgs;

        # Import our library
        selectiveWorkspace = import ./lib.nix {
          inherit pkgs;
          lib = nixpkgs.lib;
          craneLib = craneLib;
          std = nix-std.lib;
        };

      in
      {
        # Export the library
        lib = selectiveWorkspace;

        # Development shell for working on the library
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cargo
            rustc
            rust-analyzer
            clippy
            rustfmt
            nix
          ];
        };

        # Test runner that works in the examples directory
        packages = {
          test-selective-rebuild = pkgs.writeShellScriptBin "test-selective-rebuild" ''
            # Create a temporary directory and copy the example workspace
            TMPDIR=$(mktemp -d)
            cp -r ${./examples/workspace} $TMPDIR/workspace
            chmod -R +w $TMPDIR/workspace
            cd $TMPDIR/workspace
            
            # Run the test
            ./selective-rebuild.sh
            
            # Clean up
            rm -rf $TMPDIR
          '';
        };

        # Apps
        apps = {
          test = flake-utils.lib.mkApp {
            drv = self.packages.${system}.test-selective-rebuild;
          };
        };
      }
    ) // {
      # Templates
      templates = {
        simple = {
          path = ./templates/simple;
          description = "Simple selective Cargo workspace";
        };
        
        full = {
          path = ./templates/full;
          description = "Full-featured selective Cargo workspace with advanced examples";
        };
        
        default = self.templates.simple;
      };
    };
}