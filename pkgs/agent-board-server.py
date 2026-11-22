import json
import os
import shlex
import subprocess
import sys
import threading
import time
from pathlib import Path

HOSTS = json.loads(os.environ["AGENT_BOARD_HOSTS"])
VIEW = os.environ["AGENT_BOARD_VIEW"]
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "agent-board"
PENDING = STATE / "pending"
SSH_DOWN = 255
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=4"]
OUTCOMES = ("DONE", "BLOCKED:", "FAILED:")
PICKER = Path.home() / "ghq/github.com/conao3/agents-share/tools/pick-model.py"
BB_HOST = next(host for host, spec in HOSTS.items() if "bb" in spec["harnesses"])
pending_lock = threading.Lock()


def log(*parts):
    print(*parts, flush=True)


def vb(*args, check=True):
    done = subprocess.run(["vb", *args], capture_output=True, text=True)
    if check and done.returncode != 0:
        raise RuntimeError(f"vb {' '.join(args)}: {done.stdout}{done.stderr}")
    return done


def vb_json(*args):
    return json.loads(vb(*args, "--json").stdout)


def task_root(task):
    return vb_json("read", str(task))["message"]


def on_host(host, argv, text=None, timeout=None):
    dest = HOSTS[host]["ssh"]
    cmd = ["agent-board-local", *argv] if dest is None else [*SSH, dest, shlex.join(["agent-board-local", *argv])]
    try:
        return subprocess.run(cmd, input=text or "", capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as e:
        return subprocess.CompletedProcess(cmd, SSH_DOWN, e.stdout or "", f"timed out after {timeout}s")


def reachable(host):
    return HOSTS[host]["ssh"] is None or subprocess.run([*SSH, HOSTS[host]["ssh"], "true"], capture_output=True).returncode == 0


def deliver(host, argv, text=""):
    with pending_lock:
        queued = any(json.loads(f.read_text())["host"] == host for f in PENDING.glob("*.json"))
        if not queued and on_host(host, argv, text, timeout=120).returncode == 0:
            return
        (PENDING / f"{time.time_ns()}.json").write_text(json.dumps({"host": host, "args": argv, "input": text}))
        log(f"queued for {host}: {argv}")


def retry_loop():
    while True:
        time.sleep(60)
        with pending_lock:
            down = set()
            for f in sorted(PENDING.glob("*.json")):
                item = json.loads(f.read_text())
                if item["host"] in down:
                    continue
                if on_host(item["host"], item["args"], item["input"], timeout=120).returncode == 0:
                    f.unlink()
                    log(f"delivered {f.name} to {item['host']}")
                else:
                    down.add(item["host"])


def tail(name, handle):
    cursor_file = STATE / f"{name}.cursor"
    while True:
        args = ["vb", "tail", "work/", "--json"]
        if cursor_file.exists() and cursor_file.read_text().strip():
            args += ["--after", cursor_file.read_text().strip()]
        with subprocess.Popen(args, stdout=subprocess.PIPE, text=True) as proc:
            for line in proc.stdout:
                event = json.loads(line)
                try:
                    handle(event)
                except Exception as e:
                    log(f"{name}: {e}")
                cursor_file.write_text(event["cursor"])
        time.sleep(10)


def to_muse(task, state):
    thread_file = STATE / "notify.muse-thread"
    text = (
        f"[helios] [factory] board のタスク #{task} が {state} になった。{VIEW}/?thread={task}\n"
        f"vb read {task} でスレッドを読み、completed なら結果を、blocked なら質問と選択肢を、failed なら理由を、パパに短く伝えて。"
        "パパは board のタスクへの返信で答えるので、board には書き込まないで。"
    )
    target = thread_file.read_text().strip() if thread_file.exists() else "new"
    sent = subprocess.run(["musewire", "chat", "send-message", "--thread-id", target, "--text", text], capture_output=True, text=True, check=True)
    if target == "new":
        thread_file.write_text(json.loads(sent.stdout)["ThreadId"])


def notify(event):
    kind = event["type"]
    if kind not in ("task.completed", "task.blocked", "task.failed"):
        return
    task = event["payload"]["id"]
    root = task_root(task)
    state = root["task"]["state"]
    if kind != f"task.{state}":
        return
    target = root["labels"].get("notify")
    if target is None:
        to_muse(task, state)
    else:
        where, thread = target.split(":", 1)
        harness, host = where.split("@", 1)
        text = (
            f"[factory] Board task #{task}, which you created, is now {state}. {VIEW}/?thread={task}\n"
            f"Run: BOARD_URL={VIEW}/api/board vb read {task}\n"
            f"If it is completed, check the result and decide whether to queue follow-up tasks. "
            f"If it is blocked, answer it with vb reply {task} \"<answer>\" or ask the owner. "
            f"If it is failed, decide whether to reopen it with vb tasks reopen {task}."
        )
        deliver(host, ["send", harness, thread], text)
    log(f"notified {target or 'muse'}: task {task} {state}")


def replies(event):
    message = event.get("message") or {}
    if event["type"] != "message.posted" or message.get("re") is None:
        return
    task = message["re"]
    root = task_root(task)
    labels = root["labels"]
    by = message["by"]
    if "host" not in labels or "thread" not in labels:
        return
    if by.get("profile") is not None and by["actor"] != root["by"]["actor"]:
        return
    state = root["task"]["state"]
    log(f"reply on task {task} ({state}) for {labels['harness']} thread {labels['thread']}")
    if state == "blocked":
        vb("tasks", "unblock", task)
    elif state == "failed":
        vb("tasks", "reopen", task)
    else:
        try:
            model_args = pick_model(task, labels, labels["harness"])
        except ValueError as e:
            log(str(e))
            model_args = []
        deliver(labels["host"], ["nudge", labels["harness"], labels["thread"], task, *model_args])


def pick_model(task, labels, harness):
    if "model" not in labels:
        raise ValueError(f"Task #{task} has no model label. Add one with: vb label {task} model=<fable|opus|sonnet|haiku>")
    args = [sys.executable, str(PICKER), "board", labels["model"], "--harness", harness]
    if harness == "bb":
        args += ["--bb", os.environ["AGENT_BOARD_BB_CATALOG"]]
    if "effort" in labels:
        args += ["--effort", labels["effort"]]
    picked = subprocess.run(args, capture_output=True, text=True, env={**os.environ, "AGENT_BOARD_BB_HOST": BB_HOST})
    if picked.returncode != 0:
        effort = f" effort={labels['effort']}" if "effort" in labels else ""
        raise ValueError(f"Task #{task} has model={labels['model']}{effort}, which picks no model: {(picked.stderr or picked.stdout).strip()}")
    pick = json.loads(picked.stdout)
    model_args = ["--provider", pick["provider"], "--model", pick["model"]]
    if "effort" in pick:
        model_args += ["--reasoning-level", pick["effort"]]
    return model_args


def until_reachable(host):
    while not reachable(host):
        time.sleep(60)


def keep_claim(task, profile, stop):
    while not stop.wait(300):
        vb("tasks", "renew", task, "--as", profile, check=False)


def outcome(text):
    lines = [line.strip() for line in text.strip().splitlines() if line.strip()]
    last = lines[-1] if lines else ""
    for word in OUTCOMES:
        if last.startswith(word):
            return word.rstrip(":").lower(), last[len(word):].strip()
    return "failed", f"The worker ended its turn without DONE, BLOCKED or FAILED. Its last line: {last[:300]}"


def work(host, harness, task, profile):
    try:
        model_args = pick_model(task, task_root(task)["labels"], harness)
    except ValueError as e:
        return "failed", str(e)
    started = on_host(host, ["start", harness, task, *model_args], timeout=600)
    if started.returncode != 0:
        return "failed", started.stderr.strip() or f"agent-board-local start exited {started.returncode}"
    thread, runs = started.stdout.split()[-2:]
    log(f"task {task} runs in {harness} thread {thread} on {host}")
    while True:
        until_reachable(host)
        waited = on_host(host, ["wait", harness, thread, runs])
        if waited.returncode == 0:
            return outcome(waited.stdout)
        if waited.returncode != SSH_DOWN:
            return "failed", waited.stderr.strip() or f"agent-board-local wait exited {waited.returncode}"
        log(f"lost {host} while waiting on task {task}; waiting for it to come back")


def lane(host, harness):
    profile = f"runner-{host}-{harness}"
    while True:
        until_reachable(host)
        people = [a["id"] for a in vb_json("actors")["actors"] if a["kind"] == "person"]
        froms = [arg for person in people for arg in ("--from", person)]
        claimed = vb("tasks", "claim", "--ready", "work/", "--label", f"host={host}", "--label", f"harness={harness}", *froms, "--wait", "10m", "--json", "--as", profile, check=False)
        if claimed.returncode != 0:
            if '"timeout"' not in claimed.stdout:
                log(f"{profile}: {claimed.stdout}{claimed.stderr}")
                time.sleep(30)
            continue
        task = json.loads(claimed.stdout)["task"]["id"]
        log(f"{profile} claimed task {task}")
        stop = threading.Event()
        threading.Thread(target=keep_claim, args=(task, profile, stop), daemon=True).start()
        try:
            state, text = work(host, harness, task, profile)
        except Exception as e:
            state, text = "failed", f"agent-board-server: {e}"
        stop.set()
        if state == "done":
            vb("tasks", "complete", task, text or "done", "--as", profile)
        elif state == "blocked":
            vb("tasks", "block", task, text, "--as", profile)
        else:
            vb("tasks", "fail", task, text, "--as", profile)
        log(f"task {task} {state}")


def main():
    PENDING.mkdir(parents=True, exist_ok=True)
    workers = [threading.Thread(target=retry_loop), threading.Thread(target=tail, args=("notify", notify)), threading.Thread(target=tail, args=("replies", replies))]
    workers += [threading.Thread(target=lane, args=(host, harness)) for host, spec in HOSTS.items() for harness in spec["harnesses"]]
    for w in workers:
        w.daemon = True
        w.start()
    while all(w.is_alive() for w in workers):
        time.sleep(5)
    sys.exit("agent-board-server: a loop stopped")


main()
