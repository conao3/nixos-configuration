{ lib, buildGraalvmNativeImage, fetchurl}:
buildGraalvmNativeImage rec {
  pname = "cljstyle";
  version = "0.16.626";

  src = fetchurl {
    url = "https://github.com/greglook/cljstyle/releases/download/${version}/cljstyle-${version}.jar";
    sha256 = "";
  };
}
