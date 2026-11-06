{
  writeShellApplication,
  linkFarm,
  python3,
  coreutils,
  curl,
  gawk,
  gnugrep,
  jq,
  openssl,
  procps,
}:
let
  modal = writeShellApplication {
    name = "cgpu-modal";
    runtimeInputs = [
      (python3.withPackages (ps: [ ps.modal ]))
      coreutils
      curl
      gawk
      gnugrep
      jq
      openssl
      procps
    ];
    text = ''
      MODAL_DIR="${./modal}"
    ''
    + builtins.readFile ./modal/modal.sh;
  };
  services = linkFarm "cgpu-services" [
    {
      name = "modal";
      path = "${modal}/bin/cgpu-modal";
    }
  ];
in
writeShellApplication {
  name = "cgpu";
  runtimeInputs = [ coreutils ];
  text = ''
    SERVICES_DIR="${services}"
  ''
  + builtins.readFile ./cgpu.sh;
}
