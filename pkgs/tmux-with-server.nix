{
  coreutils,
  symlinkJoin,
  systemd,
  tmux,
  writeShellScript,
}:

let
  wrapper = writeShellScript "tmux" ''
    real=${tmux}/bin/tmux
    case " $* " in
      *" -L"* | *" -S"*) exec "$real" "$@" ;;
    esac
    if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
      export TMUX_TMPDIR="''${TMUX_TMPDIR:-$XDG_RUNTIME_DIR}"
    fi
    if [ -z "''${TMUX:-}" ] && [ -n "''${XDG_RUNTIME_DIR:-}" ] && ! "$real" ls >/dev/null 2>&1; then
      ${systemd}/bin/systemctl --user start tmux-server.service >/dev/null 2>&1 || true
      for _ in $(${coreutils}/bin/seq 40); do
        "$real" ls >/dev/null 2>&1 && break
        ${coreutils}/bin/sleep 0.05
      done
    fi
    exec "$real" "$@"
  '';
in
symlinkJoin {
  name = "tmux-with-server-${tmux.version}";
  paths = [
    tmux
    tmux.man
  ];
  postBuild = ''
    rm "$out/bin/tmux"
    cp ${wrapper} "$out/bin/tmux"
  '';
  meta.mainProgram = "tmux";
}
