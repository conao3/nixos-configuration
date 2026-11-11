{ callPackage }:

callPackage (import ./make-brave.nix rec {
  pname = "brave";
  version = "1.99.56";
  archives = {
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
      hash = "sha256-W1r00Qh1j+XoK3yxGa8gOXepD8s0ubBzGTF/hj84vHI=";
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
