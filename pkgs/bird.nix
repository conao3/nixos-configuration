{
  lib,
  buildNpmPackage,
  nodejs_25,
  makeWrapper,
}:

buildNpmPackage {
  pname = "bird";
  version = "0.8.0";

  src = ./bird;
  npmDepsHash = "sha256-DZTSmfKoxUBTnXsPqqv2fP770wHW2r67sfn104MPlt4=";

  nodejs = nodejs_25;
  nativeBuildInputs = [ makeWrapper ];

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/bird $out/bin
    cp -R node_modules package.json package-lock.json $out/lib/bird/

    makeWrapper ${nodejs_25}/bin/node $out/bin/bird \
      --add-flags $out/lib/bird/node_modules/@steipete/bird/dist/cli.js

    runHook postInstall
  '';

  meta = {
    description = "Fast X CLI for tweeting, replying, and reading via Twitter/X GraphQL API";
    homepage = "https://www.npmjs.com/package/@steipete/bird";
    license = lib.licenses.mit;
    mainProgram = "bird";
  };
}
