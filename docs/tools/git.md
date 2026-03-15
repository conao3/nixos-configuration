# Git Tips

## 別ブランチから master を fast-forward する

worktree やブランチを切り替えずに、現在のブランチから master を fast-forward できる。

```sh
git fetch . feature-branch:master
```

### 仕組み

- `git fetch` は本来「リモートの参照をローカルに反映する」コマンド
- `.` を指定すると自分自身がリモート扱いになる
- refspec `<src>:<dst>` で「ソースの ref をデスティネーションの ref に書き込む」動作をする
- fast-forward できない場合は拒否されるので安全

### 比較

`merge --ff-only` でも同じことができるが、ブランチ切り替えが必要：

```sh
git switch master && git merge --ff-only feature-branch && git switch feature-branch
```

`git fetch .` なら切り替え不要で1コマンドで済む。
