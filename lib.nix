{
  pkgs,
  lib,
  craneLib,
  std ? null,
}:

let
  # Fallback TOML serializer if std is not provided
  toTOML = if std != null then std.serde.toTOML else
    # Simple TOML serializer fallback
    attrs: builtins.toJSON attrs; # This is a simplified fallback

  # Main workspace builder function
  mkWorkspace = {
    src,
    # Optional parameters with defaults
    sourceFilter ? craneLib.filterCargoSources,
    # All crane.buildPackage parameters are passed through
    ...
  }@args:
  let
    workspaceRoot = src;
    
    # Remove our custom parameters from args to pass the rest to crane
    craneArgs = builtins.removeAttrs args [ "src" "sourceFilter" ];

    # Load the workspace toml to build a dependency graph of child crates
    workspaceToml = builtins.fromTOML (builtins.readFile (workspaceRoot + "/Cargo.toml"));

    # Get crate information for a workspace member
    getWorkspaceMemberInfo = memberPath:
      let
        cratePath = workspaceRoot + "/${memberPath}";
        cargoToml = builtins.fromTOML (builtins.readFile (cratePath + "/Cargo.toml"));
      in
      {
        name = cargoToml.package.name;
        path = memberPath;
        dependencies = builtins.attrNames (cargoToml.dependencies or { });
      };

    workspaceMembers = map getWorkspaceMemberInfo workspaceToml.workspace.members;
    workspaceMembersByName = builtins.listToAttrs (
      map (m: {
        name = m.name;
        value = m;
      }) workspaceMembers
    );

    # Build a transitive dependency closure for each workspace crate
    getWorkspaceDependencies = targetCrate:
      let
        go = crateName: seen:
          if builtins.elem crateName seen then
            [ ]
          else if !(builtins.hasAttr crateName workspaceMembersByName) then
            [ ]
          else
            let
              crate = workspaceMembersByName.${crateName};
              workspaceDeps = builtins.filter (
                dep: builtins.hasAttr dep workspaceMembersByName
              ) crate.dependencies;
              newSeen = seen ++ [ crateName ];
              transitive = lib.flatten (map (dep: go dep newSeen) workspaceDeps);
            in
            [ crateName ] ++ transitive;
      in
      lib.unique (go targetCrate [ ]);

    # Create a filtered workspace Cargo.toml for a specific crate
    createFilteredWorkspace = targetCrate:
      let
        relevantCrates = getWorkspaceDependencies targetCrate;
        relevantPaths = map (name: workspaceMembersByName.${name}.path) relevantCrates;

        # Create new workspace toml with only relevant members
        filteredWorkspace = workspaceToml // {
          workspace = workspaceToml.workspace // {
            members = relevantPaths;
          };
        };
      in
      pkgs.writeText "Cargo.toml" (toTOML filteredWorkspace);

    # Create source filter for a specific crate that includes its dependencies
    createSourceFilter = {
      targetCrate,
      sourceFilter ? craneLib.filterCargoSources,
    }:
      let
        relevantCrates = getWorkspaceDependencies targetCrate;
        relevantPaths = map (name: workspaceMembersByName.${name}.path) relevantCrates;
      in
      path: type:
      let
        pathStr = toString path;
        rootStr = toString workspaceRoot;
        relativePath = lib.removePrefix (rootStr + "/") pathStr;

        # Skip the original workspace Cargo.toml, we replace it with our own
        isOriginalWorkspaceCargoToml = relativePath == "Cargo.toml";

        # Always include workspace-level files that match the filter except the original Cargo.toml
        isWorkspaceFile =
          (!lib.hasInfix "/" relativePath) && !isOriginalWorkspaceCargoToml && (sourceFilter path type);

        # Check if this path is within a relevant crate directory
        isInRelevantCrate = builtins.any (
          cratePath: lib.hasPrefix (cratePath + "/") relativePath || relativePath == cratePath
        ) relevantPaths;

        # For directories, include if they're relevant crate directories or subdirectories
        isRelevantDirectory =
          type == "directory"
          && (
            # The crate directory itself
            builtins.elem relativePath relevantPaths
            ||
            # Subdirectories of relevant crates
            builtins.any (cratePath: lib.hasPrefix (cratePath + "/") relativePath) relevantPaths
          );

        # For files, be more selective
        isRelevantFile = sourceFilter path type;

        # Include if it's a workspace file, or if it's in a relevant crate
        shouldInclude = isWorkspaceFile || (isInRelevantCrate && (isRelevantDirectory || isRelevantFile));
      in
      shouldInclude;

    # Build a crate with only it and its deps
    buildCrateWithFilteredSource = {
      memberInfo,
      extraArgs ? {},
    }:
      let
        # Merge crane args with any extra args for this specific crate
        finalArgs = craneArgs // extraArgs;
        
        # Create source that only includes this crate + its workspace dependencies
        baseSource = lib.cleanSourceWith {
          src = workspaceRoot;
          filter = createSourceFilter {
            targetCrate = memberInfo.name;
            inherit sourceFilter;
          };
        };

        # Include the filtered workspace Cargo.toml
        filteredSource = pkgs.runCommand "${memberInfo.name}-filtered-source" { } ''
          cp -r ${baseSource} $out
          chmod -R +w $out
          cp ${createFilteredWorkspace memberInfo.name} $out/Cargo.toml
        '';

        # Let crane handle the crate name/version detection
        crateNameInfo = craneLib.crateNameFromCargoToml {
          cargoToml = workspaceRoot + "/${memberInfo.path}/Cargo.toml";
        };
      in
      craneLib.buildPackage (finalArgs // {
        inherit (crateNameInfo) pname version;
        src = filteredSource;
        cargoExtraArgs = "--package ${memberInfo.name}";
        cargoLock = workspaceRoot + "/Cargo.lock";
      });

    # Build all crates
    crateDerivations = builtins.listToAttrs (
      map (memberInfo: {
        name = memberInfo.name;
        value = buildCrateWithFilteredSource { inherit memberInfo; };
      }) workspaceMembers
    );

    # Build a specific crate with custom args
    buildCrate = crateName: extraArgs:
      if builtins.hasAttr crateName workspaceMembersByName then
        buildCrateWithFilteredSource {
          memberInfo = workspaceMembersByName.${crateName};
          inherit extraArgs;
        }
      else
        throw "Crate '${crateName}' not found in workspace";

  in
  {
    # All crates built with default settings
    crates = crateDerivations;
    
    # Function to build a specific crate with custom crane args
    inherit buildCrate;
    
    # Utility functions for advanced usage
    utils = {
      inherit workspaceMembers workspaceMembersByName;
      getDependencies = getWorkspaceDependencies;
      getSourceFilter = createSourceFilter;
      getFilteredWorkspace = createFilteredWorkspace;
    };
  };

in
{
  inherit mkWorkspace;
}