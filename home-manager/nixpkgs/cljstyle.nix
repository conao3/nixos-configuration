{ lib
, buildGraalvmNativeImage
, fetchurl
,
}:

buildGraalvmNativeImage rec {
  pname = "cljstyle";
  version = "0.16.626";

  src = fetchurl {
    url = "https://github.com/greglook/${pname}/releases/download/${version}/${pname}-${version}.jar";
    sha256 = "sha256-b6kWPFrYvoDu3g0ZSAw/L6rRxGfStBgkM1u9VZl6/x8=";
  };

  extraNativeImageBuildArgs = [
    "-H:+ReportExceptionStackTraces"
    "-H:Log=registerResource:"
    "--initialize-at-build-time"
    "--diagnostics-mode"
    "--report-unsupported-elements-at-runtime"
    "--no-fallback"
  ];
}
