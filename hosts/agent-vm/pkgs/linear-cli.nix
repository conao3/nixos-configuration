{ stdenvNoCC, fetchurl, lib, ... }:

stdenvNoCC.mkDerivation rec {
  pname = "linear-cli";
  version = "1.10.0";

  src = fetchurl {
    url =
      if stdenvNoCC.hostPlatform.system == "x86_64-linux" then
        "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-x86_64-unknown-linux-gnu.tar.xz"
      else if stdenvNoCC.hostPlatform.system == "aarch64-linux" then
        "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-aarch64-unknown-linux-gnu.tar.xz"
      else
        throw "linear-cli: unsupported system ${stdenvNoCC.hostPlatform.system}";

    hash =
      if stdenvNoCC.hostPlatform.system == "x86_64-linux" then
        "sha256-UZUYUkcHmh/cCM2xAxAeJrG1sdBj1fTB2n7HknjTdVg="
      else if stdenvNoCC.hostPlatform.system == "aarch64-linux" then
        "sha256-QhBfvG5T67x3zpVVkcTPx+WL2+5niMYXbmoq/Hx2fko="
      else
        lib.fakeHash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 linear -t $out/bin

    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for Linear issue tracker";
    homepage = "https://github.com/schpet/linear-cli";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "linear";
  };
}
