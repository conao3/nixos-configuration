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
    rev = "b0e0ff0082236a73c12a48483d0c6036fdd31fe1";
    hash = "sha256-4gsuQmSX9/DC8PtXs448x1EU9EqOVjeHlEF9molpv+Q=";
  };

  mixFodDeps = beamPkgs.fetchMixDeps {
    pname = "symphony-deps";
    version = "0.1.0";
    src = "${src}/elixir";
    hash = "sha256-523u3y5kjnmbKLunK+yWJb+8BgPYy+STqfCjVi3zRy4=";
  };
in
beamPkgs.mixRelease {
  pname = "symphony";
  version = "0.1.0";
  src = "${src}/elixir";
  inherit mixFodDeps;
  escriptBinName = "bin/symphony";
}
