{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
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

  # hermes-webui v0.51.3 expects hermes_cli.kanban_db, which is present on
  # Hermes Agent main but not in the currently packaged v2026.4.30 build.
  # Keep the packaged Hermes Agent as-is and expose only the missing module to
  # the WebUI through a small symlink overlay.
  kanbanDb = fetchurl {
    url = "https://raw.githubusercontent.com/NousResearch/hermes-agent/601e5f1d57cfd4ceefee50a6df05a860a1a602e8/hermes_cli/kanban_db.py";
    sha256 = "0jv2b020sf9ag3yshf11gaj3xfqzb9hc7cjzcp3d0slc507s6iaq";
  };
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

    agentSite="${hermes-agent}/${python3.sitePackages}"
    agentOverlay="$out/share/hermes-agent-overlay"
    mkdir -p "$agentOverlay" "$agentOverlay/hermes_cli"
    for path in "$agentSite"/*; do
      name="$(basename "$path")"
      if [ "$name" != "hermes_cli" ]; then
        ln -s "$path" "$agentOverlay/$name"
      fi
    done
    for path in "$agentSite/hermes_cli"/*; do
      ln -s "$path" "$agentOverlay/hermes_cli/$(basename "$path")"
    done
    ln -sf ${kanbanDb} "$agentOverlay/hermes_cli/kanban_db.py"

    makeWrapper ${pythonEnv.interpreter} "$out/bin/hermes-webui" \
      --add-flags "$out/share/hermes-webui/server.py" \
      --set-default HERMES_WEBUI_AGENT_DIR "$agentOverlay" \
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
