{
  common = [
    (import ./go.nix)
  ];
  linux = [
    (import ./waydroid-nftables.nix)
  ];
  darwin = [
    (import ./crates-io-static.nix)
  ];
}
