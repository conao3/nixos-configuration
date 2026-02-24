{
  lib,
  stdenv,
  fetchzip,
  system,
}:

let
  sources = {
    "x86_64-linux" = {
      url = "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_amd64.tar.gz";
      sha256 = "0ayh4v4bnrfl21ry2zzrzsjn8c9va3fx6i9sns89qv3i1avylf9b";
    };
    "aarch64-linux" = {
      url = "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_arm64.tar.gz";
      sha256 = lib.fakeHash;
    };
    "aarch64-darwin" = {
      url = "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_darwin_arm64.tar.gz";
      sha256 = "sha256-y/NgmM52UWARr34JFVoKyR35Q2gJp5PEo+IpMbZwFMo=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_darwin_amd64.tar.gz";
      sha256 = lib.fakeHash;
    };
  };
  src = sources.${system} or (throw "gogcli: unsupported system: ${system}");
in

stdenv.mkDerivation {
  pname = "gogcli";
  version = "0.11.0";

  src = fetchzip {
    inherit (src) url sha256;
    stripRoot = false;
  };

  installPhase = ''
    mkdir -p $out/bin
    install -m755 gog $out/bin/gog
  '';

  meta = {
    description = "Google Suite CLI: Gmail, GCal, GDrive, GContacts";
    homepage = "https://github.com/steipete/gogcli";
    license = lib.licenses.mit;
    mainProgram = "gog";
    platforms = lib.platforms.unix;
  };
}
