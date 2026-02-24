{ ... }:
{
  programs.git = {
    enable = true;
    # lfs.enable = true;

    ignores = import ../ext/git-ignore.nix;

    settings = {
      user = {
        name = "conao3";
        email = "conao3@gmail.com";
      };
      core = {
        hooksPath = "~/.config/git/hooks";
        # quotepath = false;
        # fsmonitor = true;
        # untrackedcache = true;
      };
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
  };
}
