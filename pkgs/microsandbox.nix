{
  autoPatchelfHook,
  fetchurl,
  lib,
  libcap_ng,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "microsandbox";
  version = "0.4.6";

  src = fetchurl {
    url = "https://github.com/superradcompany/microsandbox/releases/download/v${version}/microsandbox-linux-x86_64.tar.gz";
    hash = "sha256-gCb8yykJBNJ8Y0v19hhdOPu+UVyUEoHkZ2fQ93Jvbac=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    libcap_ng
    stdenv.cc.cc.lib
  ];

  sourceRoot = ".";

  appendRunpaths = [ "${placeholder "out"}/lib" ];

  installPhase = ''
    runHook preInstall

    install -Dm755 msb -t $out/bin
    ln -s msb $out/bin/microsandbox

    install -Dm644 libkrunfw.so.5.2.1 -t $out/lib
    ln -s libkrunfw.so.5.2.1 $out/lib/libkrunfw.so.5
    ln -s libkrunfw.so.5 $out/lib/libkrunfw.so

    runHook postInstall
  '';

  meta = {
    description = "microVM sandbox for AI agents (libkrun-based, OCI-compatible)";
    homepage = "https://microsandbox.dev/";
    license = lib.licenses.asl20;
    mainProgram = "msb";
    platforms = [ "x86_64-linux" ];
  };
}
