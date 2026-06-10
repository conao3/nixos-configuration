{
  callPackage,
  buildFHSEnv,
  asar,
  src,
}:

let
  patchy-cnb = callPackage (src + "/pkgs/patchy-cnb.nix") { };
  claude-desktop = callPackage (src + "/pkgs/claude-desktop.nix") {
    inherit patchy-cnb;
    nodePackages = {
      inherit asar;
    };
  };
in
buildFHSEnv {
  name = "claude-desktop";
  targetPkgs =
    pkgs': with pkgs'; [
      docker
      glibc
      openssl
      nodejs
      uv
    ];
  runScript = "${claude-desktop}/bin/claude-desktop";
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/

    mkdir -p $out/share/icons
    cp -r ${claude-desktop}/share/icons/* $out/share/icons/
  '';
}
