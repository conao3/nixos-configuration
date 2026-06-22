{
  common = [
    (import ./go.nix)
  ];
  linux = [
    (import ./cursor.nix)
  ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
