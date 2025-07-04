{
  pkgs,
  lib,
  crane,
  std,
}:

let
  workspaceRoot = ./..;

  # load the workspace toml to build a dependency graph of child crates
  workspaceToml = builtins.fromTOML (builtins.readFile (workspaceRoot + "/Cargo.toml"));

  # get crate information for a workspace member
  getWorkspaceMemberInfo =
    memberPath:
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

  # build a transitive dependency closure for each workspace crate
  getWorkspaceDependencies =
    targetCrate:
    let
      go =
        crateName: seen:
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

  # create a filtered workspace Cargo.toml for a specific crate that will only build that crate and its deps
  createFilteredWorkspace =
    targetCrate:
    let
      relevantCrates = getWorkspaceDependencies targetCrate;
      relevantPaths = map (name: workspaceMembersByName.${name}.path) relevantCrates;

      # create new workspace toml with only relevant members
      filteredWorkspace = workspaceToml // {
        workspace = workspaceToml.workspace // {
          members = relevantPaths;
        };
      };
    in
    pkgs.writeText "Cargo.toml" (std.serde.toTOML filteredWorkspace);

  # create source filter for a specific crate that includes its dependencies
  createSourceFilter =
    {
      targetCrate,
      sourceFilter ? crane.filterCargoSources,
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
      fileName = baseNameOf path;

      # skip the original workspace Cargo.toml, we replace it with our own modified one
      isOriginalWorkspaceCargoToml = relativePath == "Cargo.toml";

      # always include workspace-level files that match the filter except the original Cargo.toml
      # this by default includes Cargo.lock, etc
      isWorkspaceFile =
        (!lib.hasInfix "/" relativePath) && !isOriginalWorkspaceCargoToml && (sourceFilter path type);

      # check if this path is within a relevant crate directory
      isInRelevantCrate = builtins.any (
        cratePath: lib.hasPrefix (cratePath + "/") relativePath || relativePath == cratePath
      ) relevantPaths;

      # for directories, include if they're relevant crate directories or subdirectories
      isRelevantDirectory =
        type == "directory"
        && (
          # the crate directory itself
          builtins.elem relativePath relevantPaths
          ||
            # subdirectories of relevant crates
            builtins.any (cratePath: lib.hasPrefix (cratePath + "/") relativePath) relevantPaths
        );

      # for files, be more selective
      isRelevantFile = sourceFilter path type;

      # Include if it's a workspace file, or if it's in a relevant crate
      shouldInclude = isWorkspaceFile || (isInRelevantCrate && (isRelevantDirectory || isRelevantFile));

    in
    shouldInclude;

  # build a crate with only it and its deps
  buildCrateWithFilteredSource =
    {
      memberInfo,
      sourceFilter ? crane.filterCargoSources,
    }:
    let
      # create source that only includes this crate + its workspace dependencies
      baseSource = lib.cleanSourceWith {
        src = workspaceRoot;
        filter = createSourceFilter {
          targetCrate = memberInfo.name;
          sourceFilter = sourceFilter;
        };
      };

      # include the filtered workspace Cargo.toml
      filteredSource = pkgs.runCommand "${memberInfo.name}-filtered-source" { } ''
        cp -r ${baseSource} $out
        chmod -R +w $out

        cp ${createFilteredWorkspace memberInfo.name} $out/Cargo.toml
      '';

      # let crane handle the crate name/version detection
      crateNameInfo = crane.crateNameFromCargoToml {
        cargoToml = workspaceRoot + "/${memberInfo.path}/Cargo.toml";
      };

    in
    crane.buildPackage {
      inherit (crateNameInfo) pname version;

      src = filteredSource;

      cargoExtraArgs = "--package ${memberInfo.name}";
      cargoLock = workspaceRoot + "/Cargo.lock";
    };

  # build all crates
  crateDerivations = builtins.listToAttrs (
    map (memberInfo: {
      name = memberInfo.name;
      value = buildCrateWithFilteredSource { memberInfo = memberInfo; };
    }) workspaceMembers
  );

in
{
  crates = crateDerivations;

  # Debugging helper
  debug = {
    inherit workspaceMembers workspaceMembersByName;
    getDependencies = getWorkspaceDependencies;
    getSourceFilter = createSourceFilter;
    getFilteredWorkspace = createFilteredWorkspace;
  };
}
