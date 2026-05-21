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
    owner = "sapsaldog";
    repo = "symphony";
    rev = "932e5f423bf1fd17c067677a6b42e4910e98047e";
    hash = "sha256-d4IYBwJl4gVJIARB9GDLLp/td+S8o9xtU4p7NjxqAzs=";
  };

  mixFodDeps = beamPkgs.fetchMixDeps {
    pname = "symphony-claude-deps";
    version = "0.1.0";
    src = "${src}/elixir";
    hash = "sha256-523u3y5kjnmbKLunK+yWJb+8BgPYy+STqfCjVi3zRy4=";
  };
in
beamPkgs.mixRelease {
  pname = "symphony-claude";
  version = "0.1.0";
  src = "${src}/elixir";
  inherit mixFodDeps;
  escriptBinName = "bin/symphony";
  postInstall = ''
    mv "$out/bin/symphony" "$out/bin/symphony-claude"
  '';
}
