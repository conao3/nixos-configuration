{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_26,
}:
let
  version = "1.9.4";
  buildGoModule' = buildGoModule.override { go = go_1_26; };
in
buildGoModule' {
  pname = "ghq";
  inherit version;

  src = fetchFromGitHub {
    owner = "x-motemen";
    repo = "ghq";
    rev = "v${version}";
    hash = "sha256-z7tLCSThR4EFLk8GnyrB8H6d/9t5AKegVEdzlleCS94=";
  };

  vendorHash = "sha256-/uk1hf5eXpNULKm7UeVgQ7Lc7YOU+eV9Yd/4lYorz/8=";

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Remote repository management made easy";
    homepage = "https://github.com/x-motemen/ghq";
    license = lib.licenses.mit;
    mainProgram = "ghq";
  };
}
