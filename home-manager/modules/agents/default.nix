{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.agents;
  agentsLib = import ./lib.nix { inherit lib; };
  mcpLib = import ./mcp.nix { inherit lib; };
  mkShare = import ./share.nix { inherit pkgs lib; };
  formats = {
    json = pkgs.formats.json { };
    toml = pkgs.formats.toml { };
  };
  homeDirectory = config.home.homeDirectory;

  instancesOf = typeName: lib.filterAttrs (_: inst: inst.type == typeName) cfg.instances;
  sharedInstancesOf =
    typeName:
    lib.filterAttrs (_: inst: cfg.types.${typeName}.share.enable && inst.share) (instancesOf typeName);
  standaloneInstances = lib.filterAttrs (
    _: inst: !(cfg.types.${inst.type}.share.enable && inst.share)
  ) cfg.instances;

  configDirsOf =
    t: lib.optional (t.homeDir != null) t.homeDir ++ lib.optional t.share.enable t.share.dir;

  configScopedNames = t: lib.attrNames (lib.filterAttrs (_: f: f.scope == "config") t.files);

  fileTargets =
    typeName: t: fileName: file:
    let
      dirs =
        if file.scope == "config" then
          configDirsOf t
        else
          lib.mapAttrsToList (_: inst: inst.dir) (instancesOf typeName);
    in
    map (dir: "${dir}/${fileName}") dirs ++ file.extraTargets;

  fileSettings =
    typeName: t: fileName: file: target:
    let
      base =
        if lib.isFunction file.settings then
          file.settings { dir = dirOf "${homeDirectory}/${target}"; }
        else
          file.settings;
      servers = mcpLib.render {
        inherit (t.mcp) format;
        inherit typeName;
      } cfg.mcpServers;
    in
    if t.mcp != null && builtins.elem fileName t.mcp.files then
      base // { ${t.mcp.key} = agentsLib.force servers; }
    else
      base;

  storeName = s: lib.strings.sanitizeDerivationName "agents-${s}";

  generated =
    typeName: t: fileName: file: target:
    if file.source != null then
      file.source
    else
      formats.${file.format}.generate (storeName "${typeName}-${fileName}") (
        agentsLib.resolve (fileSettings typeName t fileName file target)
      );

  agentsMerge = pkgs.writeShellScript "agents-merge" ''
    set -euo pipefail
    format=$1
    target=$2
    ops=$3
    label=$4
    warnFile=$5
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
    if [ ! -f "$target" ] || [ ! -s "$target" ]; then
      current='{}'
    elif [ "$format" = toml ]; then
      current=$(${lib.getExe pkgs.yq-go} -p toml -o json "$target")
    else
      current=$(${pkgs.coreutils}/bin/cat "$target")
    fi
    out=$(printf '%s' "$current" \
      | ${lib.getExe pkgs.jq} --slurpfile ops "$ops" --arg label "$label" --arg target "$target" -f ${./merge.jq})
    tmp=$(${pkgs.coreutils}/bin/mktemp "$(${pkgs.coreutils}/bin/dirname "$target")/.agents-merge.XXXXXX")
    warnings=$(printf '%s' "$out" | ${lib.getExe pkgs.jq} -r '.warnings[]')
    if [ -n "$warnings" ]; then
      printf '%s\n' "$warnings" >> "$warnFile"
    fi
    if [ "$format" = toml ]; then
      printf '%s' "$out" | ${lib.getExe pkgs.jq} '.result' \
        | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$tmp"
    else
      printf '%s' "$out" | ${lib.getExe pkgs.jq} '.result' > "$tmp"
    fi
    ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
    ${pkgs.coreutils}/bin/mv -T "$tmp" "$target"
  '';

  activationFor =
    typeName: t: fileName: file: target:
    let
      path = ''"$HOME/${target}"'';
      ops = pkgs.writeText "${storeName "${typeName}-${fileName}"}-ops.json" (
        builtins.toJSON (agentsLib.flatten file.onConflict (fileSettings typeName t fileName file target))
      );
    in
    if file.strategy == "merge" then
      ''${agentsMerge} ${file.format} ${path} ${ops} ${lib.escapeShellArg "${typeName} settings"} "$warnFile"''
    else
      ''
        mkdir -p "$(dirname ${path})"
        rm -f ${path}
        ${pkgs.coreutils}/bin/install -m 0644 ${generated typeName t fileName file target} ${path}
      '';

  perTarget =
    f:
    lib.concatLists (
      lib.mapAttrsToList (
        typeName: t:
        lib.concatLists (
          lib.mapAttrsToList (
            fileName: file:
            map (target: f typeName t fileName file target) (fileTargets typeName t fileName file)
          ) t.files
        )
      ) cfg.types
    );

  linkedFiles = lib.listToAttrs (
    lib.filter (x: x != null) (
      perTarget (
        typeName: t: fileName: file: target:
        if file.strategy == "link" then
          lib.nameValuePair target { source = generated typeName t fileName file target; }
        else
          null
      )
    )
  );

  activeFiles = lib.filter (x: x != null) (
    perTarget (
      typeName: t: fileName: file: target:
      if file.strategy != "link" then activationFor typeName t fileName file target else null
    )
  );

  instructionFiles =
    lib.optionalAttrs (cfg.instructions != null) (
      {
        "${cfg.common.dir}/${cfg.common.instructionsFile}".source = cfg.instructions;
      }
      // lib.mapAttrs' (
        _: t: lib.nameValuePair "${t.share.dir}/${t.instructionsFile}" { source = cfg.instructions; }
      ) (lib.filterAttrs (_: t: t.share.enable) cfg.types)
    )
    //
      lib.mapAttrs'
        (
          _: inst:
          lib.nameValuePair "${inst.dir}/${cfg.types.${inst.type}.instructionsFile}" {
            source = if inst.instructions != null then inst.instructions else cfg.instructions;
          }
        )
        (
          lib.filterAttrs (_: inst: inst.instructions != null || cfg.instructions != null) standaloneInstances
        );

  mkWrapper =
    {
      name,
      executable,
      envVar,
      dir,
      makeWrapperArgs,
    }:
    pkgs.runCommand name { buildInputs = [ pkgs.makeWrapper ]; } ''
      makeWrapper ${executable} $out/bin/${name} \
        --run 'export ${envVar}="$HOME/${dir}"'${
          lib.optionalString (makeWrapperArgs != [ ]) " ${lib.escapeShellArgs makeWrapperArgs}"
        }
    '';

  wrapperPackages = lib.concatLists (
    lib.mapAttrsToList (
      name: inst:
      let
        t = cfg.types.${inst.type};
      in
      lib.optional inst.wrapper.enable (mkWrapper {
        inherit name;
        inherit (t) executable envVar;
        inherit (inst) dir;
        inherit (inst.wrapper) makeWrapperArgs;
      })
      ++ lib.mapAttrsToList (
        exeName: w:
        mkWrapper {
          name = exeName;
          executable = if w.executable != null then w.executable else t.executable;
          inherit (t) envVar;
          inherit (inst) dir;
          inherit (w) makeWrapperArgs;
        }
      ) inst.extraWrappers
    ) cfg.instances
  );

  quote = s: ''"${s}"'';
in
{
  imports = [ ./options.nix ];

  config = lib.mkMerge [
    {
      _module.args.agentsLib = {
        inherit (agentsLib) force delete migrate;
      };
    }
    (lib.mkIf cfg.enable {
      assertions =
        lib.mapAttrsToList (name: inst: {
          assertion = cfg.types ? ${inst.type};
          message = "programs.agents.instances.${name}: unknown type '${inst.type}'";
        }) cfg.instances
        ++ lib.mapAttrsToList (name: inst: {
          assertion = !(cfg.types.${inst.type}.share.enable && inst.share) || inst.instructions == null;
          message = "programs.agents.instances.${name}: instructions of a shared instance come from programs.agents.instructions";
        }) cfg.instances
        ++ lib.mapAttrsToList (name: srv: {
          assertion = (srv.url == null) != (srv.command == null);
          message = "programs.agents.mcpServers.${name}: set exactly one of url and command";
        }) cfg.mcpServers
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: srv:
            map (typeName: {
              assertion = cfg.types ? ${typeName} && cfg.types.${typeName}.mcp != null;
              message = "programs.agents.mcpServers.${name}.enableFor: type '${typeName}' has no mcp output";
            }) srv.enableFor
          ) cfg.mcpServers
        )
        ++ lib.concatLists (
          lib.mapAttrsToList (
            typeName: t:
            lib.mapAttrsToList (fileName: file: {
              assertion = file.source == null || file.strategy != "merge";
              message = "programs.agents.types.${typeName}.files.${fileName}: source cannot be merged";
            }) t.files
          ) cfg.types
        );

      home.packages =
        wrapperPackages
        ++ lib.filter (p: p != null) (lib.mapAttrsToList (_: t: t.package) cfg.types)
        ++ lib.mapAttrsToList (
          name: target: pkgs.writeShellScriptBin name ''exec ${target} "$@"''
        ) cfg.aliases;

      home.file = instructionFiles // linkedFiles;

      home.activation.agentsDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatMapStringsSep "\n" (dir: "mkdir -p ${quote "$HOME/${dir}"}") (
          [
            cfg.baseDir
            cfg.common.dir
          ]
          ++ lib.mapAttrsToList (_: t: t.share.dir) (lib.filterAttrs (_: t: t.share.enable) cfg.types)
          ++ lib.mapAttrsToList (_: inst: inst.dir) cfg.instances
        )
      );

      home.activation.agentsCommon =
        lib.hm.dag.entryAfter
          [
            "writeBoundary"
            "agentsDirs"
          ]
          (
            lib.concatMapStringsSep "\n" (
              f:
              let
                path = quote "$HOME/${cfg.common.dir}/${f}";
              in
              ''
                if [ ! -f ${path} ]; then
                  touch ${path}
                fi
              ''
            ) cfg.common.ensureFiles
            + lib.concatMapStringsSep "\n" (
              d: "mkdir -p ${quote "$HOME/${cfg.common.dir}/${d}"}"
            ) cfg.common.directories
          );

      home.activation.agentsShare =
        lib.hm.dag.entryAfter
          [
            "writeBoundary"
            "agentsDirs"
          ]
          (
            lib.concatStrings (
              lib.mapAttrsToList (
                typeName: t:
                let
                  instructions = lib.optional (cfg.instructions != null) t.instructionsFile;
                in
                mkShare {
                  sharedDir = "$HOME/${t.share.dir}";
                  profileDirs = lib.mapAttrsToList (_: inst: "$HOME/${inst.dir}") (sharedInstancesOf typeName);
                  inherit (t.share) exclude history keepFirst;
                  forceLinks = lib.unique (t.share.forceLinks ++ instructions ++ configScopedNames t);
                  discard = lib.unique (t.share.discard ++ instructions);
                }
              ) (lib.filterAttrs (_: t: t.share.enable) cfg.types)
            )
          );

      home.activation.agentsFiles =
        lib.hm.dag.entryAfter
          [
            "writeBoundary"
            "agentsDirs"
            "agentsShare"
          ]
          ''
            warnFile=${quote "$HOME/${cfg.warningsFile}"}
            mkdir -p "$(dirname "$warnFile")"
            rm -f "$warnFile"
            ${lib.concatStringsSep "\n" activeFiles}
          '';

      programs.zsh.initContent = lib.mkIf (cfg.zshFunctions != { }) (
        lib.mkAfter (
          lib.concatStrings (
            lib.mapAttrsToList (name: body: ''
              ${name}() {
                ${body} "$@"
              }
            '') cfg.zshFunctions
          )
        )
      );

      systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
        lib.mapAttrs' (
          name: srv:
          lib.nameValuePair "${name}-mcp" {
            Unit.Description = srv.service.description;
            Service = {
              ExecStart = srv.service.execStart;
              Restart = "on-failure";
            };
            Install.WantedBy = [ "default.target" ];
          }
        ) (lib.filterAttrs (_: srv: srv.service != null) cfg.mcpServers)
      );
    })
  ];
}
