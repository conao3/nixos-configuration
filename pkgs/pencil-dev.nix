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
    hash = "sha256-31gqv4kU8LB2e84MQKcNYXTLNSeJLzmWQahz6+bi2jk=";
  };

  meta = {
    description = "Design on canvas, land in code";
    homepage = "https://www.pencil.dev";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pencil-dev";
  };
}
