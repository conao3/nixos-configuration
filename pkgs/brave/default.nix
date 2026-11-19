{ callPackage }:

callPackage (import ./make-brave.nix rec {
  pname = "brave";
  version = "1.100.58";
  archives = {
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
      hash = "sha256-LZ0eZk79YDQ8dzJMg2vkAsvlfOElSZdVhN+n0HPxVqU=";
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
