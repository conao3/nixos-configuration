{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    # lfs.enable = true;

    ignores = import ./ignore.nix;

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

  home.file.".config/git/hooks/pre-commit" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec ${pkgs.gitleaks}/bin/gitleaks git --staged --redact --no-banner
    '';
  };
}
