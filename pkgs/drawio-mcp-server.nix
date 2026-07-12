{
  lib,
  stdenvNoCC,
  fetchzip,
  makeWrapper,
  nodejs,
  cacert,
}:

let
  pname = "drawio-mcp-server";
  version = "2.2.0";

  src = fetchzip {
    name = "${pname}-${version}.tgz";
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    extension = "tar.gz";
    hash = "sha256-dKtDKauDqe1yXV5SB99CzIFOxm77BACmJnCBoPDJwd8=";
  };

  # Fixed-output derivation: npm install で runtime deps を取得する。
  # 上流 tarball は lockfile を含まないため、transitive deps の解決が変わると
  # outputHash が合わなくなる。hash mismatch が出たら got の値で更新する。
  nodeModules = stdenvNoCC.mkDerivation {
    name = "${pname}-node-modules-${version}";
    inherit src;

    nativeBuildInputs = [
      nodejs
      cacert
    ];

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-OxkWGs5q9379PpppLfPo/xHZQtjjcEdXv1Xrm8BcDA4=";

    NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    buildPhase = ''
      export HOME=$TMPDIR
      # devDependencies は未公開の workspace パッケージ (drawio-mcp-dev-proxy 等) を参照して
      # おり、--omit=dev でも npm がメタデータ解決で 404 になるため事前に削除する
      node -e '
        const fs = require("fs");
        const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
        delete p.devDependencies;
        fs.writeFileSync("package.json", JSON.stringify(p, null, 2));
      '
      npm install --omit=dev --ignore-scripts --no-audit --no-fund --no-bin-links \
        --cache $TMPDIR/npm-cache
    '';

    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/node_modules
    '';
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}
    cp -r . $out/lib/${pname}
    ln -s ${nodeModules}/node_modules $out/lib/${pname}/node_modules
    makeWrapper ${nodejs}/bin/node $out/bin/${pname} \
      --add-flags $out/lib/${pname}/build/index.js
    runHook postInstall
  '';

  meta = {
    description = "Draw.io MCP server: browser extension 経由で稼働中の draw.io エディタを増分編集する";
    homepage = "https://github.com/lgazo/drawio-mcp-server";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = lib.platforms.unix;
  };
}
