{ callPackage }:

callPackage (import ./make-brave.nix rec {
  pname = "brave";
  version = "1.99.57";
  archives = {
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
      hash = "sha256-jNFMV/f9bXnf2aJUUBdbVDihsRtWX/XQitmRtwLen9U=";
    };
  };
  optStem = "brave";
  fileStem = "brave-browser";
  appIdStem = "com.brave.Browser";
  darwinStem = "Brave Browser";
  changelogFile = "CHANGELOG_DESKTOP.md";
  homepage = "https://brave.com/";
  innerBinary = "brave";
}) { }
