{
  lib,
  runCommand,
  writeShellScript,
}:
{
  package,
  flags,
}:
let
  program = lib.getExe package;
  name = baseNameOf program;
  wrapper = writeShellScript "${name}-yolo" ''
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --yolo) args+=(${lib.escapeShellArgs flags}) ;;
        --) args+=("$@"); break ;;
        *) args+=("$1") ;;
      esac
      shift
    done
    exec ${lib.escapeShellArg program} "''${args[@]}"
  '';
in
runCommand "${package.name}-yolo"
  {
    meta.mainProgram = name;
  }
  ''
    mkdir -p $out/bin
    for f in ${package}/*; do
      [ "$(basename "$f")" = bin ] || ln -s "$f" $out/
    done
    for f in ${package}/bin/* ${package}/bin/.[!.]*; do
      [ -e "$f" ] || continue
      ln -s "$f" $out/bin/
    done
    rm $out/bin/${name}
    ln -s ${wrapper} $out/bin/${name}
  ''
