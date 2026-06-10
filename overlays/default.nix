{
  common = [
    (import ./go.nix)
    (import ./direnv.nix)
  ];
  linux = [
    (import ./node-packages.nix)
    (import ./cursor.nix)
  ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
