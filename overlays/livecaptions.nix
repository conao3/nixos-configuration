final: prev:
let
  april-model = final.fetchurl {
    url = "https://april.sapples.net/april-english-dev-01110_en.april";
    hash = "sha256-d+uV0PpPdwijfoaMImUwHubELcsl5jymPuo9nLrbwfM=";
  };
in
{
  livecaptions = final.symlinkJoin {
    name = "livecaptions-${prev.livecaptions.version}";
    paths = [ prev.livecaptions ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/livecaptions --set APRIL_MODEL_PATH ${april-model}
    '';
    inherit (prev.livecaptions) meta;
  };
}
