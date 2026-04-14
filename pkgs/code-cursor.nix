{
  lib,
  stdenv,
  buildVscode,
  fetchurl,
  appimageTools,
  undmg,
  commandLineArgs ? "",
  useVSCodeRipgrep ? stdenv.hostPlatform.isDarwin,
}:

let
  inherit (stdenv) hostPlatform;

  sources = {
    version = "3.0.16";
    vscodeVersion = "1.105.1";
    sources = {
      x86_64-linux = {
        url = "https://downloads.cursor.com/production/475871d112608994deb2e3065dfb7c6b0baa0c54/linux/x64/Cursor-3.0.16-x86_64.AppImage";
        hash = "sha256-dN8tFSppIpO/P0Thst5uaNzlmfWZDh0Y81Lx1BuSYt0=";
      };
      aarch64-linux = {
        url = "https://downloads.cursor.com/production/475871d112608994deb2e3065dfb7c6b0baa0c54/linux/arm64/Cursor-3.0.16-aarch64.AppImage";
        hash = "sha256-tG75z9SPVaH6cgN75XW1ZKRyj689Yd97cbQZSvQtPrA=";
      };
      x86_64-darwin = {
        url = "https://downloads.cursor.com/production/475871d112608994deb2e3065dfb7c6b0baa0c54/darwin/x64/Cursor-darwin-x64.dmg";
        hash = "sha256-8pGWntBuY6hwIuQ3x5yF93j0++3gB+wg/KsVfIVWUgI=";
      };
      aarch64-darwin = {
        url = "https://downloads.cursor.com/production/475871d112608994deb2e3065dfb7c6b0baa0c54/darwin/arm64/Cursor-darwin-arm64.dmg";
        hash = "sha256-HHd3CpSlGpuRUjakSCBRp3q3RYhiOapBKqblRNiQaZI=";
      };
    };
  };

  source = fetchurl sources.sources.${hostPlatform.system};
in
buildVscode rec {
  inherit commandLineArgs useVSCodeRipgrep;
  inherit (sources) version vscodeVersion;

  pname = "cursor";

  executableName = "cursor";
  longName = "Cursor";
  shortName = "cursor";
  libraryName = "cursor";
  iconName = "cursor";

  src =
    if hostPlatform.isLinux then
      appimageTools.extract {
        inherit pname version;
        src = source;
      }
    else
      source;

  extraNativeBuildInputs = lib.optionals hostPlatform.isDarwin [ undmg ];

  sourceRoot =
    if hostPlatform.isLinux then "${pname}-${version}-extracted/usr/share/cursor" else "Cursor.app";

  tests = { };
  updateScript = null;

  dontFixup = stdenv.hostPlatform.isDarwin;
  patchVSCodePath = false;

  meta = {
    description = "AI-powered code editor built on vscode";
    homepage = "https://cursor.com";
    changelog = "https://cursor.com/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [
      aspauldingcode
      prince213
      qweered
    ];
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ]
    ++ lib.platforms.darwin;
    mainProgram = "cursor";
  };
}
