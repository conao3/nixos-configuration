{
  fetchFromGitHub,
  lib,
  libsForQt5,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "texassolver";
  version = "0.2.0-unstable-2026-08-26";

  src = fetchFromGitHub {
    owner = "bupticybee";
    repo = "TexasSolver";
    rev = "d12197b6d409a10474a7138ec2fb662b02588c09";
    hash = "sha256-d9MhGyXv1KtVvoBY/q+m7r3U3W9aPWbVR6CaE4o2y6k=";
  };

  nativeBuildInputs = [
    libsForQt5.qmake
    libsForQt5.wrapQtAppsHook
  ];

  buildInputs = [ libsForQt5.qtbase ];

  qmakeFlags = [ "CONFIG+=c++17" ];

  installPhase = ''
    runHook preInstall

    install -Dm755 TexasSolverGui "$out/bin/TexasSolverGui"
    install -Dm644 resources/desktop/TexasSolverGui.desktop "$out/share/applications/TexasSolverGui.desktop"
    install -Dm644 imgs/texassolver_logo.png "$out/share/pixmaps/texassolver_logo.png"

    runHook postInstall
  '';

  meta = {
    description = "Open source Texas hold'em and short deck GTO solver";
    homepage = "https://github.com/bupticybee/TexasSolver";
    license = lib.licenses.agpl3Only;
    mainProgram = "TexasSolverGui";
    platforms = lib.platforms.linux;
  };
})
