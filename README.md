# crane-select

`crane-select` lets you build Cargo workspace crates with Crane, preventing rebuilds if you modify one crate that doesn't affect another.

## Features

- **Selective Rebuilding**: Only rebuild crates that actually depend on changed code
- **Crane Integration**: Full compatibility with Crane's `buildPackage` parameters
- **Dependency Analysis**: Automatic transitive dependency resolution (for workspace packages)

## Quick Start

### Simple Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    crane-select.url = "github:arilotter/crane-select";
  };

  outputs = { nixpkgs, crane, crane-select, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      craneLib = crane.mkLib pkgs;
      
      workspace = crane-select.lib.${system}.mkWorkspace {
        src = ./.;
        inherit (pkgs) lib;
        crane = craneLib;
      };
    in
    {
      packages.${system} = workspace.crates;
    };
}
```

### Advanced Usage

```nix
let
  workspace = crane-select.lib.${system}.mkWorkspace {
    src = ./.;
    inherit (pkgs) lib;
    crane = craneLib;
    
    # All crane.buildPackage parameters are supported
    buildInputs = [ pkgs.openssl ];
    nativeBuildInputs = [ pkgs.pkg-config ];
    CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
  };
in
{
  packages.${system} = workspace.crates // {
    # Build specific crate with custom parameters
    my-crate-static = workspace.buildCrate "my-crate" {
      CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
      buildInputs = [ pkgs.musl ];
    };
  };
}
```

## API Reference

### `mkWorkspace`

Creates a workspace builder with selective rebuilding capabilities.

**Parameters:**
- `src`: Path to the workspace root
- `sourceFilter`: Optional source filter function (defaults to `crane.filterCargoSources`)
- All other parameters are passed through to `crane.buildPackage`

**Returns:**
- `crates`: Attribute set of all workspace crates
- `buildCrate`: Function to build specific crates with custom parameters
- `utils`: Utility functions for advanced usage

### `buildCrate`

Build a specific crate with custom crane parameters.

```nix
workspace.buildCrate "crate-name" {
  # Any crane.buildPackage parameters
  buildInputs = [ ... ];
  cargoExtraArgs = "--features=extra";
}
```

### Utilities

Access internal utilities for advanced usage:

```nix
workspace.utils.getDependencies "crate-name"  # Get transitive dependencies
workspace.utils.workspaceMembers              # List all workspace members
```

## How It Works

1. **Dependency Analysis**: Parses `Cargo.toml` files to build a dependency graph
2. **Source Filtering**: Creates filtered source trees containing only relevant crates
3. **Workspace Generation**: Generates a minimal `Cargo.toml` file for the workspace to exclude unneeded crates

## Testing Selective Rebuilding

Run the test suite to verify selective rebuilding works:

```bash
# From the library root
nix run .#test

# Or manually in the examples directory
cd examples/workspace
./selective-rebuild.sh
```

The test verifies:
- Changes to unrelated crates don't trigger rebuilds
- Changes to dependency crates do trigger rebuilds

## Templates

Use `nix flake init` to get started:

- `nix flake init -t github:arilotter/crane-select#simple` - Basic setup
- `nix flake init -t github:arilotter/crane-select#full` - Complete example

## Requirements

- Nix with flakes enabled
- A Cargo workspace with at least one crate

## License

MIT