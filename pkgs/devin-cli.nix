{
  devin-cli,
  fetchurl,
  stdenvNoCC,
}:
let
  version = "3000.14.30821";
  hashes = {
    x86_64-linux = {
      target = "x86_64-unknown-linux";
      hash = "sha256-TcQ+PkOIus5g/iqoAQy7OZQC5ySJLXF1hFsc3vAOfds=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux";
      hash = "sha256-PeuK9rAmBg6XXtNxk24TmBgCDl3Fq7y6B83gOfRzpaU=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-Ru8addi9hRZlF54Ta345rVl9PXkTuV1n/SuI6civAGE=";
    };
  };
  source = hashes.${stdenvNoCC.hostPlatform.system};
in
devin-cli.overrideAttrs {
  inherit version;
  src = fetchurl {
    url = "https://static.devin.ai/cli/${version}/devin-${version}-${source.target}.tar.gz";
    inherit (source) hash;
  };
}
