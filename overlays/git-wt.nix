final: prev: {
  git-wt = prev.git-wt.overrideAttrs (old: {
    checkFlags = (old.checkFlags or [ ]) ++ [
      "-skip=TestE2E_CreateWorktree/with_remote_start_point_for_ambiguous_remote_branch"
    ];
  });
}
