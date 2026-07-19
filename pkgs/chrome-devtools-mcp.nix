{
  lib,
  stdenvNoCC,
  fetchzip,
  makeWrapper,
  nodejs,
}:

stdenvNoCC.mkDerivation rec {
  pname = "chrome-devtools-mcp";
  version = "1.6.0";

  src = fetchzip {
    name = "${pname}-${version}.tgz";
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    extension = "tar.gz";
    hash = "sha256-TM+iiOituNmPfa5F9ikuwrgHuwevhYtzr9YyviZcYHs=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # upstream は puppeteer の protocolTimeout を設定せず既定 180s のまま。共有 Chrome が
  # 別 session の重い処理 (getFullAXTree 等) でビジーだと軽量ページの captureScreenshot
  # まで 180s で失敗するため、rust-chrome-devtools daemon の heavy tool timeout (300s)
  # に合わせて注入する。CHROME_DEVTOOLS_MCP_PROTOCOL_TIMEOUT_MS で上書き可。
  postPatch = ''
    substituteInPlace build/src/browser.js \
      --replace-fail 'const connectOptions = {' \
        'const connectOptions = {
        protocolTimeout: Number(process.env.CHROME_DEVTOOLS_MCP_PROTOCOL_TIMEOUT_MS ?? 300000),'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}
    cp -r . $out/lib/${pname}
    makeWrapper ${nodejs}/bin/node $out/bin/${pname} \
      --add-flags $out/lib/${pname}/build/src/bin/chrome-devtools-mcp.js
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/${pname} --version | grep -F ${version}
    runHook postInstallCheck
  '';

  meta = {
    description = "MCP server exposing Chrome DevTools capabilities to AI coding assistants";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    license = lib.licenses.asl20;
    mainProgram = pname;
    platforms = lib.platforms.unix;
  };
}
