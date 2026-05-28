final: prev:
let
  rewrite =
    url:
    let
      m = builtins.match "https://crates\\.io/api/v1/crates/([^/]+)/([^/]+)/download" url;
    in
    if m == null then
      url
    else
      "https://static.crates.io/crates/${builtins.elemAt m 0}/${builtins.elemAt m 0}-${builtins.elemAt m 1}.crate";
in
{
  fetchurl =
    args:
    prev.fetchurl (if args ? url then args // { url = rewrite args.url; } else args);
}
