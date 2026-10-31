{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.programs.agents;

  settingsType = types.either (types.attrsOf types.anything) (
    types.functionTo (types.attrsOf types.anything)
  );

  fileModule = types.submodule (
    { name, ... }:
    {
      options = {
        scope = mkOption {
          type = types.enum [
            "config"
            "instances"
          ];
          default = "config";
          description = ''
            Directories the file is written into. `config` is the type's
            {option}`homeDir` plus its shared directory; `instances` is every
            instance directory of the type.
          '';
        };
        extraTargets = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ ".claude.json" ];
          description = "Additional targets relative to the home directory.";
        };
        format = mkOption {
          type = types.enum [
            "json"
            "toml"
          ];
          default = if lib.hasSuffix ".toml" name then "toml" else "json";
          defaultText = lib.literalMD "`toml` when the name ends in `.toml`, otherwise `json`";
          description = "Serialization of {option}`settings`.";
        };
        strategy = mkOption {
          type = types.enum [
            "merge"
            "overwrite"
            "link"
          ];
          default = "merge";
          description = ''
            How the file reaches its targets.

            - `merge`: an activation step applies {option}`settings` to the
              existing file and keeps every key it does not mention. Use this
              for files the agent writes back to.
            - `overwrite`: an activation step replaces the file with a copy of
              the generated one on every switch.
            - `link`: a read-only `home.file` symlink into the store.
          '';
        };
        source = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Copy or link this file verbatim instead of generating it from {option}`settings`.";
        };
        settings = mkOption {
          type = settingsType;
          default = { };
          description = ''
            Content as an attrset. Leaves may be wrapped with the helpers from
            the `agentsLib` module argument: `force v` replaces the subtree,
            `delete` removes the key, `migrate { from; to; }` rewrites `from`
            to `to` and leaves other values alone. A function receives
            `{ dir }`, the absolute directory of the target.
          '';
        };
        onConflict = mkOption {
          type = types.enum [
            "warn"
            "overwrite"
          ];
          default = "warn";
          description = ''
            Behaviour of plain leaves under `merge` when the file already holds
            a different value. `warn` keeps the file's value and appends a
            line to {option}`programs.agents.warningsFile`; `overwrite`
            replaces it.
          '';
        };
      };
    }
  );

  typeModule = types.submodule (
    { name, config, ... }:
    {
      options = {
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Package installed into `home.packages`.";
        };
        executable = mkOption {
          type = types.str;
          default =
            if config.package != null then
              lib.getExe config.package
            else
              throw "programs.agents.types.${name}.executable must be set when package is null";
          defaultText = lib.literalExpression "lib.getExe package";
          description = "Program the instance wrappers exec. May point at a wrapper script.";
        };
        envVar = mkOption {
          type = types.str;
          example = "CLAUDE_CONFIG_DIR";
          description = "Environment variable that selects the configuration directory.";
        };
        homeDir = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = ".claude";
          description = "Directory the agent uses when {option}`envVar` is unset, relative to the home directory.";
        };
        instructionsFile = mkOption {
          type = types.str;
          default = "AGENTS.md";
          description = "File name the agent reads its instructions from.";
        };
        share = {
          enable = mkEnableOption "a directory shared by the type's instances";
          dir = mkOption {
            type = types.str;
            default = "${cfg.baseDir}/.${name}";
            defaultText = lib.literalExpression ''"''${baseDir}/.''${name}"'';
            description = "Shared directory relative to the home directory.";
          };
          exclude = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Entries that stay per instance.";
          };
          forceLinks = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Entries linked into every instance even before the shared copy
              exists. The instructions file and the type's `config`-scoped
              files are always included.
            '';
          };
          discard = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Regular files dropped from an instance instead of being moved to
              the shared directory. The instructions file is always included.
            '';
          };
          history = {
            file = mkOption {
              type = types.str;
              default = "history.jsonl";
              description = "JSON Lines file merged across instances.";
            };
            sortKey = mkOption {
              type = types.str;
              default = ".timestamp";
              description = "jq expression the merged history is sorted by.";
            };
          };
          keepFirst = mkOption {
            type = types.listOf types.str;
            default = [
              "*.sqlite"
              "*.sqlite-shm"
              "*.sqlite-wal"
            ];
            description = "Patterns for which the first copy reaching the shared directory wins.";
          };
        };
        mcp = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                format = mkOption {
                  type = types.enum [
                    "claude"
                    "codex"
                    "cursor"
                  ];
                  description = "Shape of each rendered server entry.";
                };
                key = mkOption {
                  type = types.str;
                  description = "Top-level key holding the servers.";
                };
                files = mkOption {
                  type = types.listOf types.str;
                  description = "Names in {option}`files` that receive the servers.";
                };
              };
            }
          );
          default = null;
          description = "Where {option}`programs.agents.mcpServers` are written for this type.";
        };
        files = mkOption {
          type = types.attrsOf fileModule;
          default = { };
          description = "Configuration files keyed by their name inside the target directory.";
        };
      };
    }
  );

  wrapperArgsOption = mkOption {
    type = types.listOf types.str;
    default = [ ];
    example = [
      "--add-flags"
      "-p fugu"
    ];
    description = "Extra `makeWrapper` arguments. `--add-flags` text is expanded by the shell at run time.";
  };

  instanceModule = types.submodule (
    { name, ... }:
    {
      options = {
        type = mkOption {
          type = types.str;
          default = builtins.head (lib.splitString "." name);
          defaultText = lib.literalMD "the part of the name before the first `.`";
          description = "Name in {option}`programs.agents.types`.";
        };
        dir = mkOption {
          type = types.str;
          default = "${cfg.baseDir}/.${name}";
          defaultText = lib.literalExpression ''"''${baseDir}/.''${name}"'';
          description = "Configuration directory relative to the home directory.";
        };
        share = mkOption {
          type = types.bool;
          default = true;
          description = "Join the type's shared directory when it is enabled.";
        };
        instructions = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Instructions for an instance outside the shared directory. Defaults
            to {option}`programs.agents.instructions`.
          '';
        };
        wrapper = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Install an executable named after the instance.";
          };
          makeWrapperArgs = wrapperArgsOption;
        };
        extraWrappers = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                executable = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Program to exec. Defaults to the type's executable.";
                };
                makeWrapperArgs = wrapperArgsOption;
              };
            }
          );
          default = { };
          description = "More executables that run with this instance's directory selected.";
        };
      };
    }
  );

  serverModule = types.submodule {
    options = {
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Endpoint of a remote (HTTP) server. `\${VAR}` is expanded by the agent.";
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Executable of a local (stdio) server.";
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Arguments of {option}`command`.";
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment of {option}`command`.";
      };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "HTTP headers sent to {option}`url`.";
      };
      bearerTokenEnvVar = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "DEVIN_API_KEY";
        description = "Environment variable holding the bearer token.";
      };
      bearerTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "~/.config/flovia/key";
        description = ''
          File holding the bearer token, read by the agent on each connection.
          The value is a path, never the token. Only the `claude` format can
          render it.
        '';
      };
      enableFor = mkOption {
        type = types.listOf types.str;
        default = lib.attrNames (lib.filterAttrs (_: t: t.mcp != null) cfg.types);
        defaultText = lib.literalMD "every type with `mcp` set";
        description = "Types that receive the server.";
      };
      service = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              description = mkOption {
                type = types.str;
                description = "Unit description.";
              };
              execStart = mkOption {
                type = types.str;
                description = "Command line of the long-running server.";
              };
            };
          }
        );
        default = null;
        description = ''
          Run the server as the systemd user service `<name>-mcp` so every
          agent shares one process. Linux only.
        '';
      };
    };
  };
in
{
  options.programs.agents = {
    enable = mkEnableOption "coding agent instances";
    baseDir = mkOption {
      type = types.str;
      default = ".agents";
      description = "Parent of instance and shared directories, relative to the home directory.";
    };
    instructions = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Instructions linked into the common directory, every shared directory and every standalone instance.";
    };
    common = {
      dir = mkOption {
        type = types.str;
        default = "${cfg.baseDir}/share";
        defaultText = lib.literalExpression ''"''${baseDir}/share"'';
        description = "Directory shared by every agent regardless of type.";
      };
      instructionsFile = mkOption {
        type = types.str;
        default = "AGENTS.md";
        description = "Name of the instructions file in the common directory.";
      };
      directories = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Subdirectories created in the common directory.";
      };
      ensureFiles = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Files created empty in the common directory when missing.";
      };
    };
    warningsFile = mkOption {
      type = types.str;
      default = "${cfg.baseDir}/settings-warnings.log";
      defaultText = lib.literalExpression ''"''${baseDir}/settings-warnings.log"'';
      description = "Log of `merge` conflicts from the last activation, relative to the home directory.";
    };
    types = mkOption {
      type = types.attrsOf typeModule;
      default = { };
      description = "Agent programs.";
    };
    instances = mkOption {
      type = types.attrsOf instanceModule;
      default = { };
      description = "Configuration directories, each with its own wrapper. The attribute name is the executable name.";
    };
    aliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        pi = "pi.agent001";
      };
      description = "Executables that exec another executable found on PATH.";
    };
    mcpServers = mkOption {
      type = types.attrsOf serverModule;
      default = { };
      description = "MCP servers distributed to every type in their {option}`enableFor`.";
    };
    zshFunctions = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "zsh functions; each body is a command the call's arguments are appended to.";
    };
  };
}
