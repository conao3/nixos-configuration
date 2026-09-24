{
  common = [
    (import ./curl-cffi.nix)
    (import ./go.nix)
  ];
  linux = [
    (import ./livecaptions.nix)
    (import ./tigervnc.nix)
  ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
