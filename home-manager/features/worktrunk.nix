{ inputs, ... }:
{
  imports = [ (inputs.home-manager-worktrunk + "/modules/programs/worktrunk.nix") ];

  programs.worktrunk.enable = true;

  # 新規 worktree 作成時に primary worktree のローカル独自版 (CLAUDE.md, AGENTS.md,
  # .mcp.json, .claude/ 配下) をコピーし、skip-worktree を立てて git status に出さない
  # ようにする。詳細: ~/.agents/share/notes/playbook/git-ignore-claude-config.md
  xdg.configFile."worktrunk/config.toml" = {
    force = true;
    text = ''
      [post-start]
      copy-agent-config = """
      set -e
      MAIN={{ primary_worktree_path }}
      cd {{ worktree_path }}

      # .claude/ 配下の追跡ファイル
      if [ -d "$MAIN/.claude" ]; then
        git ls-files .claude/ | while IFS= read -r f; do
          [ -e "$MAIN/$f" ] && [ -e "$f" ] && \
            cp "$MAIN/$f" "$f" && \
            git update-index --skip-worktree "$f"
        done
      fi

      # 単独ファイル
      for f in .mcp.json AGENTS.md CLAUDE.md; do
        [ -e "$MAIN/$f" ] && [ -e "$f" ] && \
          cp "$MAIN/$f" "$f" && \
          git update-index --skip-worktree "$f"
      done
      """
    '';
  };
}
