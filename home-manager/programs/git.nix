{
  enable = true;
  # lfs.enable = true;

  userName = "conao3";
  userEmail = "conao3@gmail.com";

  ignores = import ../ext/git-ignore.nix;

  extraConfig = {
    # core = {
    #   quotepath = false;
    #   fsmonitor = true;
    #   untrackedcache = true;
    # };
    init = {
      defaultBranch = "master";
    };
    help = {
      autoCorrect = "immediate";
    };
    fetch = {
      prune = true;
    };
    rebase = {
      autoStash = true;
      autoSquash = true;
    };
    merge = {
      conflictstyle = "diff3";
    };
    color = {
      ui = "auto";
      status = "auto";
      diff = "auto";
      branch = "auto";
      interactive = "auto";
      grep = "auto";
    };
    rerere = {
      enabled = true;
    };
  };
}
