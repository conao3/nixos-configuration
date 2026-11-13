import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())

with tempfile.TemporaryDirectory(prefix="ghq-sync-test-") as directory:
    root = Path(directory)
    home = root / "home"
    home.mkdir()
    env = dict(os.environ, HOME=str(home), GIT_CONFIG_NOSYSTEM="1",
               GIT_CONFIG_GLOBAL=str(home / ".gitconfig"), GIT_SSH_VARIANT="ssh",
               XDG_CACHE_HOME=str(root / "cache"), GHQ_ROOT=str(root / "repos"))
    for name in ["GIT_DIR", "GIT_WORK_TREE", "GIT_SSH_COMMAND"]:
        env.pop(name, None)

    def run(*args, cwd=None, expected=0):
        result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
        assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
        return result

    def git(*args, cwd=None):
        return run("git", *args, cwd=cwd).stdout.strip()

    git("config", "--global", "user.email", "test@example.invalid")
    git("config", "--global", "user.name", "Test")
    git("config", "--global", "init.defaultBranch", "master")
    git("config", "--global", "ghq.root", str(root / "repos"))
    remote = root / "remote.git"
    seed = root / "seed"
    repo = root / "repos/github.com/conao3/example"
    git("init", "--bare", str(remote))
    git("clone", str(remote), str(seed))
    (seed / "base").write_text("base\n")
    git("add", ".", cwd=seed)
    git("commit", "-m", "base", cwd=seed)
    git("push", "origin", "master", cwd=seed)
    repo.parent.mkdir(parents=True)
    git("clone", str(remote), str(repo))
    ssh = root / "ssh"
    ssh.write_text(f"#!{sys.executable}\n" + """import json, os, pathlib, subprocess, sys
root = pathlib.Path(os.environ['TEST_STATE'])
with (root / 'ssh-args').open('a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
failures = root / 'failures'
remaining = int(failures.read_text())
if remaining:
    failures.write_text(str(remaining - 1))
    sys.exit(255)
sys.exit(subprocess.call(['sh', '-c', sys.argv[-1]]))
""")
    ssh.chmod(0o700)
    env["TEST_STATE"] = str(root)
    (root / "failures").write_text("0")
    git("remote", "set-url", "origin", f"ssh://example.invalid{remote}", cwd=repo)
    git("config", "core.sshCommand", str(ssh), cwd=repo)

    for args in [["--jobs=0"], ["--connect-timeout=0"], ["--fetch-retries=-1"], ["-j"], ["--no-ssh-reuse=true"]]:
        run(binary, *args, expected=2)
    run(binary, "--repo", str(repo), "--fetch-retries=0")
    args = json.loads((root / "ssh-args").read_text().splitlines()[-1])
    assert "ControlMaster=auto" in args
    control_path = next(arg.split("=", 1)[1] for arg in args if arg.startswith("ControlPath="))
    assert not Path(control_path).parent.exists()
    run(binary, "--no-ssh-reuse", "--repo", str(repo))
    assert "ControlMaster=auto" not in json.loads((root / "ssh-args").read_text().splitlines()[-1])
    (root / "failures").write_text("1")
    result = run(binary, "--repo", str(repo), "--connect-timeout=3", "--fetch-retries=1")
    assert "fetch retry 1/1" in result.stderr
    assert "ConnectTimeout=3" in (root / "ssh-args").read_text()
    (root / "failures").write_text("2")
    assert "FETCH-FAIL" in run(binary, "--repo", str(repo), expected=1).stdout
    assert (root / "failures").read_text() == "0"

    (seed / "upstream").write_text("upstream\n")
    git("add", ".", cwd=seed)
    git("commit", "-m", "upstream", cwd=seed)
    git("push", cwd=seed)
    (repo / "base").write_text("local draft\n")
    run(binary, "--repo", str(repo))
    assert (repo / "upstream").read_text() == "upstream\n"
    assert (repo / "base").read_text() == "local draft\n"
    git("add", ".", cwd=repo)
    git("commit", "-m", "local", cwd=repo)
    assert "PUSHED (1 commits)" in run(binary, "--repo", str(repo)).stdout
    assert git("rev-parse", "HEAD", cwd=repo) == git("rev-parse", "master", cwd=remote)

    result = run(binary, "-j2", "--connect-timeout=4", "--fetch-retries=0")
    assert "all repositories are up to date" in result.stdout
    assert "ConnectTimeout=4" in (root / "ssh-args").read_text()
    (root / "failures").write_text("1")
    assert "FETCH-FAIL" in run(binary, "--jobs=2", "--fetch-retries=0", expected=1).stdout
    git("checkout", "--detach", cwd=repo)
    assert "SKIP(detached-head)" in run(binary, "--repo", str(repo)).stdout
    git("checkout", "master", cwd=repo)
    git("branch", "--unset-upstream", cwd=repo)
    assert "SKIP(no-upstream)" in run(binary, "--repo", str(repo)).stdout
    print("PASS: options, SSH timeout, retry recovery/exhaustion, autostash, push, all-repository propagation, failures, skips")
