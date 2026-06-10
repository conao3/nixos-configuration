{
  common = [
    (import ./go.nix)
    (import ./direnv.nix)
  ];
  linux = [
    (import ./cursor.nix)
  ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
