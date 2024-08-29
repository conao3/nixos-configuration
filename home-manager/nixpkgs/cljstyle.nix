{ lib, buildGraalvmNativeImage, fetchurl, nix-update-script, testers, cljstyle }:
buildGraalvmNativeImage rec {
  pname = "cljstyle";
  version = "0.16.626";

  src = fetchurl {
    url = "https://github.com/greglook/${pname}/releases/download/${version}/${pname}-${version}.jar";
    sha256 = "";
  };

  extraNativeImageBuildArgs = [
    "-H:+ReportExceptionStackTraces"
    "-H:Log=registerResource:"
    "--initialize-at-build-time"
    "--diagnostics-mode"
    "--report-unsupported-elements-at-runtime"
    "--no-fallback"
  ];

  passthru.updateScript = nix-update-script {};

  passthru.tests.version = testers.testVersion {
    inherit version;
    package = cljstyle;
    command = "cljstyle --version";
  };

  meta = with lib; {
    mainProgram = "cljstyle";
    description = "Tool for formatting Clojure code";
    homepage = "https://github.com/greglook/cljstyle";
    sourceProvenance = with sourceTypes; [ binaryBytecode ];
    license = licenses.epl10;
    changelog = "https://github.com/greglook/cljstyle/blob/${version}/CHANGELOG.md";
  };
}
