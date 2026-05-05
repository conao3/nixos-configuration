{
  lib,
  fetchurl,
  python3,
  runtimeShell,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cli-proxy-api-management-center";
  version = "1.10.1";

  src = fetchurl {
    url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.10.1/management.html";
    hash = "sha256-IL6k534dh4l3AH0aqCtpavWRIdrgQtE0Gs0SaSIh9RI=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -d "$out/bin" "$out/share/cli-proxy-api-management-center"
    install -m 0644 "$src" "$out/share/cli-proxy-api-management-center/management.html"
    ln -s management.html "$out/share/cli-proxy-api-management-center/index.html"

    cat > "$out/bin/cli-proxy-api-management-center" <<EOF
    #!${runtimeShell}
    set -eu

    host="''${CLIPROXY_MGMT_CENTER_HOST:-127.0.0.1}"
    port="''${CLIPROXY_MGMT_CENTER_PORT:-8788}"

    exec ${python3}/bin/python3 -m http.server "\$port" \
      --bind "\$host" \
      --directory "$out/share/cli-proxy-api-management-center"
    EOF
    chmod +x "$out/bin/cli-proxy-api-management-center"

    runHook postInstall
  '';

  meta = {
    description = "Single-file Web UI for CLIProxyAPI Management API";
    homepage = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api-management-center";
    platforms = lib.platforms.unix;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
})
