{ pkgs, ... }:
{
  home.file = {
    ".config" = {
      source = ./.config;
      recursive = true;
    };
    ".claude" = {
      source = ./ext/.claude;
      recursive = true;
    };
    ".config/Claude/claude_desktop_config.json" = {
      text = builtins.toJSON {
        globalShortcut = "Alt+Cmd+Space";
        mcpServers = {
          claude-code = {
            command = "${pkgs.claude-code}/bin/claude";
            args = [
              "mcp"
              "serve"
            ];
          };
        };
      };
    };
    ".config/nrepl/nrepl.edn".source = ./ext/nrepl.edn;
    ".config/wezterm/wezterm.lua".source = ./ext/wezterm.lua;
    ".config/zellij/config.kdl".source = ./ext/zellij__config.kdl;
    ".config/zellij/layouts/sando.kdl".source = ./ext/zellij__layouts__sando.kdl;
    ".config/git/hooks/pre-commit" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        exec ${pkgs.gitleaks}/bin/gitleaks git --staged --redact --no-banner
      '';
    };
    ".config/fcitx5/config".text = ''
      [Hotkey]
      EnumerateWithTriggerKeys=True
      AltTriggerKeys=
      EnumerateForwardKeys=
      EnumerateBackwardKeys=
      EnumerateSkipFirst=False
      TogglePreedit=
      ModifierOnlyKeyTimeout=250

      [Hotkey/TriggerKeys]
      0=Alt+space

      [Hotkey/EnumerateGroupForwardKeys]
      0=Super+space

      [Hotkey/EnumerateGroupBackwardKeys]
      0=Shift+Super+space

      [Hotkey/ActivateKeys]
      0=Hangul_Hanja

      [Hotkey/DeactivateKeys]
      0=Hangul_Romaja

      [Hotkey/PrevPage]
      0=Up

      [Hotkey/NextPage]
      0=Down

      [Hotkey/PrevCandidate]
      0=Shift+Tab

      [Hotkey/NextCandidate]
      0=Tab

      [Behavior]
      ActiveByDefault=False
      resetStateWhenFocusIn=No
      ShareInputState=All
      PreeditEnabledByDefault=True
      ShowInputMethodInformation=True
      showInputMethodInformationWhenFocusIn=False
      CompactInputMethodInformation=True
      ShowFirstInputMethodInformation=True
      DefaultPageSize=5
      OverrideXkbOption=False
      CustomXkbOption=
      EnabledAddons=
      DisabledAddons=
      PreloadInputMethod=True
      AllowInputMethodForPassword=False
      ShowPreeditForPassword=False
      AutoSavePeriod=30
    '';
  };
}
