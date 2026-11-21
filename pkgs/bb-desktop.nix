{
  appimageTools,
  fetchurl,
  lib,
}:
let
  pname = "bb-desktop";
  version = "0.49.0";
  src = fetchurl {
    url = "https://github.com/get-bb/bb/releases/download/desktop-v${version}/bb-${version}-x86_64.AppImage";
    hash = "sha256-g0mrdzcVYk/sUIJznIF9KhWAlQRpnTS0fT2d++YPx3A=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  dieWithParent = false;

  extraInstallCommands = ''
    install -Dm644 ${contents}/bb.desktop $out/share/applications/bb-desktop.desktop
    substituteInPlace $out/share/applications/bb-desktop.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=bb-desktop' \
      --replace-fail 'Icon=bb' 'Icon=bb-desktop'
    install -Dm644 ${contents}/bb.png $out/share/icons/hicolor/1024x1024/apps/bb-desktop.png
  '';

  meta = {
    description = "Desktop application for the bb agentic IDE";
    homepage = "https://github.com/get-bb/bb";
    license = lib.licenses.mit;
    mainProgram = "bb-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
