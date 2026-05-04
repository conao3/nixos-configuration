{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "pencil-dev";
  version = "2025.1.0";
in
appimageTools.wrapType2 {
  inherit pname version;

  src = fetchurl {
    url = "https://www.pencil.dev/download/Pencil-linux-x86_64.AppImage";
    hash = "sha256-pu7KAEUQh3k/tcvy58P3u6L3wUf/wY2PxV6VhKS+AC0=";
  };

  meta = {
    description = "Design on canvas, land in code";
    homepage = "https://www.pencil.dev";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pencil-dev";
  };
}
