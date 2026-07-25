{ inputs, system, ... }:
{
  imports = [ inputs.codex-desktop-linux.homeManagerModules.default ];

  programs.codexDesktopLinux = {
    enable = true;
    cliPackage = inputs.llm-agents.packages.${system}.codex;
  };
}
