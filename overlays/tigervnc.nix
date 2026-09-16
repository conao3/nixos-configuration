final: prev: {
  tigervnc = final.symlinkJoin {
    name = "tigervnc-${prev.tigervnc.version}";
    paths = [ prev.tigervnc ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vncviewer --add-flags -RemoteResize=0
    '';
    inherit (prev.tigervnc) meta;
  };
}
