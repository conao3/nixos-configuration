{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
  openssl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "portless";
  version = "0.13.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha256-9Nulh7bMTBF6oGnWtt6RdiJ3ZJKumHgnKf2SKkA+omg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -d $out/lib/portless
    cp -r dist package.json $out/lib/portless/

    makeWrapper ${nodejs}/bin/node $out/bin/portless \
      --add-flags "$out/lib/portless/dist/cli.js" \
      --prefix PATH : ${lib.makeBinPath [ openssl ]}

    runHook postInstall
  '';

  meta = {
    description = "Replace port numbers with stable, named .localhost URLs";
    homepage = "https://portless.sh";
    license = lib.licenses.asl20;
    mainProgram = "portless";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}
