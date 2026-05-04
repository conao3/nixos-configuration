{
  lib,
  stdenvNoCC,
  babashka,
  makeWrapper,
  cacert,
  src,
}:
let
  pname = "clojure-mcp-light";
  version = "0.2.2";

  # Fixed-output derivation: download Maven/Clojars deps via babashka
  mvnDeps = stdenvNoCC.mkDerivation {
    name = "${pname}-mvn-${version}";
    inherit src;

    nativeBuildInputs = [
      babashka
      cacert
    ];

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-/OX4iGZZqE3LB+IVnp9ELIOzVslqdQYaNpOmTonR2Vo=";

    NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    buildPhase = ''
      export HOME=$TMPDIR
      export JAVA_TOOL_OPTIONS="-Duser.home=$TMPDIR"
      # Trigger dep download by running a trivial eval (bb.edn deps load on startup)
      bb -e 'nil'
    '';

    installPhase = ''
      mkdir -p $out/m2/repository
      if [ -d "$HOME/.m2/repository" ]; then
        cp -r $HOME/.m2/repository/. $out/m2/repository/
      fi
      # Record relative jar paths (one per line)
      find $out/m2/repository -name "*.jar" | sort \
        | sed "s|^$out/m2/repository/||" \
        > $out/jars
    '';
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -d $out/lib/${pname}
    cp -r src $out/lib/${pname}/

    classpath="$(
      sed 's|^|${mvnDeps}/m2/repository/|;s|$|:|' ${mvnDeps}/jars | tr -d '\n'
    )$out/lib/${pname}/src"

    makeWrapper ${babashka}/bin/bb $out/bin/clj-paren-repair-claude-hook \
      --set BABASHKA_CLASSPATH "$classpath" \
      --add-flags "-m clojure-mcp-light.hook"

    makeWrapper ${babashka}/bin/bb $out/bin/clj-nrepl-eval \
      --set BABASHKA_CLASSPATH "$classpath" \
      --add-flags "-m clojure-mcp-light.nrepl-eval"

    makeWrapper ${babashka}/bin/bb $out/bin/clj-paren-repair \
      --set BABASHKA_CLASSPATH "$classpath" \
      --add-flags "-m clojure-mcp-light.paren-repair"

    runHook postInstall
  '';

  meta = {
    description = "CLI utilities for Clojure coding with LLM assistants";
    homepage = "https://github.com/bhauman/clojure-mcp-light";
    license = lib.licenses.epl20;
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}
