{
  lib,
  buildNpmPackage,
  nodejs_24,
  src,
}:

buildNpmPackage {
  pname = "cosense-cli";
  version = "1.6.0";

  inherit src;

  nodejs = nodejs_24;

  npmDepsHash = "sha256-PBnEeAR3AuUxRYjpH0ZiUHBd5Hwu+WVBiDGVVzIxwlE=";

  dontNpmBuild = true;

  meta = {
    description = "Cosense (旧Scrapbox) のページを読み・調べ・編集するAgent Skill用のCLI";
    homepage = "https://github.com/helpfeel/cosense-cli";
    license = lib.licenses.mit;
    mainProgram = "cosense";
  };
}
