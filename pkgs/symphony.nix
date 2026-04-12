{
  beamPackages,
  fetchFromGitHub,
}:
let
  beamPkgs = beamPackages.extend (
    _final: _prev: {
      elixir = beamPackages.elixir_1_19;
    }
  );

  src = fetchFromGitHub {
    owner = "openai";
    repo = "symphony";
    rev = "9e89dd9ff0a3eddb8813c77f633ca4534d6e14b2";
    hash = "sha256-0ViFsZlW4/3uH8AnuqLYlmwRu03HEGwfhB2NZIHFqY8=";
  };

  mixFodDeps = beamPkgs.fetchMixDeps {
    pname = "symphony-deps";
    version = "0.1.0";
    src = "${src}/elixir";
    hash = "sha256-JdEnj95ol5raofHmyy18/bx+1akj/K3gxkxAnT1Lk2s=";
  };
in
beamPkgs.mixRelease {
  pname = "symphony";
  version = "0.1.0";
  src = "${src}/elixir";
  inherit mixFodDeps;
  escriptBinName = "bin/symphony";
}
