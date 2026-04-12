{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
let
  version = "0.16.3";
in
buildGoModule {
  pname = "gh-poi";
  inherit version;

  src = fetchFromGitHub {
    owner = "seachicken";
    repo = "gh-poi";
    rev = "v${version}";
    hash = "sha256-oRSvd5O/izfvs+sf8RW3b2aUoMG7FRJ1pWxjCMegKp8=";
  };

  vendorHash = "sha256-UHkNSTRH9m6H8Wh7S7uUy5SHuGe0uAmmYuoeR76C7m0=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Safely clean up your local branches";
    homepage = "https://github.com/seachicken/gh-poi";
    license = lib.licenses.mit;
    mainProgram = "gh-poi";
  };
}
