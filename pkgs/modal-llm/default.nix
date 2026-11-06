{
  writeShellApplication,
  python3,
  coreutils,
  curl,
  gnugrep,
  gnused,
  jq,
  openssl,
  procps,
}:
let
  python = python3.withPackages (ps: [ ps.modal ]);
in
writeShellApplication {
  name = "modal-llm";
  runtimeInputs = [
    python
    coreutils
    curl
    gnugrep
    gnused
    jq
    openssl
    procps
  ];
  text = ''
    APP_FILE="${./app.py}"
  ''
  + builtins.readFile ./modal-llm.sh;
}
