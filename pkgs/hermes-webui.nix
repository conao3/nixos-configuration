{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  hermes-agent,
}:

let
  pythonEnv = python3.withPackages (
    ps:
    [
      ps.pyyaml
      hermes-agent
    ]
    ++ (hermes-agent.propagatedBuildInputs or [ ])
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hermes-webui";
  version = "0.51.3-unstable-2026-05-03";

  src = fetchFromGitHub {
    owner = "nesquena";
    repo = "hermes-webui";
    rev = "1cde702d47240f233d1c7031a357cc15b2bd4b24";
    hash = "sha256-7zUDGCWNC/whuC4V79E3Nye+J0/M8ehTN75EWArGx2s=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/hermes-webui"
    cp -R . "$out/share/hermes-webui"

    makeWrapper ${pythonEnv.interpreter} "$out/bin/hermes-webui" \
      --add-flags "$out/share/hermes-webui/server.py" \
      --set-default HERMES_WEBUI_AGENT_DIR "${hermes-agent}/${python3.sitePackages}" \
      --set-default HERMES_WEBUI_AUTO_INSTALL "0"

    runHook postInstall
  '';

  meta = {
    description = "Lightweight web interface for Hermes Agent";
    homepage = "https://github.com/nesquena/hermes-webui";
    license = lib.licenses.mit;
    mainProgram = "hermes-webui";
    platforms = lib.platforms.unix;
  };
})
