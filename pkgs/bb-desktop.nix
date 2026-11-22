{
  alsa-lib,
  appimageTools,
  at-spi2-atk,
  at-spi2-core,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  expat,
  fetchurl,
  glib,
  gtk3,
  lib,
  libappindicator-gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  makeWrapper,
  nspr,
  nss,
  pango,
  stdenv,
  systemd,
  vulkan-loader,
}:
let
  pname = "bb-desktop";
  version = "0.49.0";
  src = fetchurl {
    url = "https://github.com/get-bb/bb/releases/download/desktop-v${version}/bb-${version}-x86_64.AppImage";
    hash = "sha256-g0mrdzcVYk/sUIJznIF9KhWAlQRpnTS0fT2d++YPx3A=";
  };
  contents = appimageTools.extract { inherit pname version src; };
  runtimeLibs = [
    libGL
    libnotify
    libappindicator-gtk3
    libpulseaudio
    libsecret
    systemd
    vulkan-loader
  ];
in
stdenv.mkDerivation {
  inherit pname version;
  src = contents;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    libx11
    libxscrnsaver
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
    libxcb
    libxshmfence
  ]
  ++ runtimeLibs;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/bb-desktop $out/bin
    cp -r --no-preserve=mode . $out/opt/bb-desktop
    cd $out/opt/bb-desktop
    rm -rf AppRun usr/lib chrome-sandbox
    chmod +x bb chrome_crashpad_handler
    find resources/app.asar.unpacked/node_modules -path '*/prebuilds/*' -name '*.node' \
      ! -path '*/linux-x64/*' ! -name linux-x64.node -delete
    rm -rf resources/app.asar.unpacked/node_modules/@parcel/watcher-linux-{arm64-glibc,arm64-musl,x64-musl}

    makeWrapper $out/opt/bb-desktop/bb $out/bin/bb-desktop \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    install -Dm644 bb.desktop $out/share/applications/bb-desktop.desktop
    substituteInPlace $out/share/applications/bb-desktop.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=bb-desktop' \
      --replace-fail 'Icon=bb' 'Icon=bb-desktop'
    install -Dm644 usr/share/icons/hicolor/1024x1024/apps/bb.png \
      $out/share/icons/hicolor/1024x1024/apps/bb-desktop.png

    runHook postInstall
  '';

  meta = {
    description = "Desktop application for the bb agentic IDE";
    homepage = "https://github.com/get-bb/bb";
    license = lib.licenses.mit;
    mainProgram = "bb-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
