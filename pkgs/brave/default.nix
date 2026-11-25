{ callPackage }:

callPackage (import ./make-brave.nix rec {
  pname = "brave";
  version = "1.100.59";
  archives = {
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
      hash = "sha256-7/KSV8VpdKeddKqMFo1QYlV9o2wMgsjCQS3nD9yxeGE=";
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
