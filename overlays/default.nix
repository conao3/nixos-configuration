{
  common = [
    (import ./curl-cffi.nix)
    (import ./go.nix)
  ];
  linux = [
    (import ./tigervnc.nix)
  ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
