final: prev: {
  # direnv 2.37.1 uses -linkmode=external in Makefile which requires CGO.
  # Work around the nixpkgs regression by enabling CGO.
  direnv = prev.direnv.overrideAttrs (old: {
    env = (old.env or { }) // {
      CGO_ENABLED = "1";
    };
  });
}
