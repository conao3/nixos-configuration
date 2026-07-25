{
  inputs,
  pkgs,
  system,
  ...
}:
let
  basePackage = inputs.codex-desktop-linux.packages.${system}.codex-desktop;
  webviewPort = "15175";
in
{
  imports = [ inputs.codex-desktop-linux.homeManagerModules.default ];

  programs.codexDesktopLinux = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "${basePackage.name}-webview-port";
      paths = [ basePackage ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm -f $out/bin/codex-desktop
        makeWrapper ${basePackage}/bin/codex-desktop $out/bin/codex-desktop \
          --set-default CODEX_WEBVIEW_PORT ${webviewPort}
        desktopFile=$out/share/applications/codex-desktop.desktop
        target="$(readlink -f "$desktopFile")"
        rm -f "$desktopFile"
        substitute "$target" "$desktopFile" \
          --replace-fail "${basePackage}/bin/codex-desktop" "$out/bin/codex-desktop"
      '';
      meta = basePackage.meta or { };
    };
    cliPackage = inputs.llm-agents.packages.${system}.codex;
  };
}
