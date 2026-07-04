{
  lib,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "agmsg";
  version = "1.1.5";

  inherit src;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/agmsg
    cp -r scripts $out/share/agmsg/
    cp -r plugins $out/share/agmsg/
    cp SKILL.md $out/share/agmsg/
    cp openai.yaml $out/share/agmsg/
    cp uninstall.sh $out/share/agmsg/
    cp VERSION $out/share/agmsg/

    chmod +x $out/share/agmsg/scripts/*.sh
    chmod +x $out/share/agmsg/scripts/drivers/types/codex/*.sh 2>/dev/null || true
    chmod +x $out/share/agmsg/uninstall.sh

    runHook postInstall
  '';

  meta = {
    description = "Cross-agent messaging for CLI AI agents";
    homepage = "https://github.com/fujibee/agmsg";
    license = lib.licenses.mit;
  };
}
