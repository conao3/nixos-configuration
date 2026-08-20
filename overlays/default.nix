{
  common = [
    (import ./curl-cffi.nix)
    (import ./go.nix)
  ];
  linux = [ ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
