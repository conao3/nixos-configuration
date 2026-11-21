import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "t3-thread-monitor.sh"
THREAD = "test-thread"


def response(status, pending=0):
    return {
        "thread": {"threadId": THREAD, "status": status, "pendingRequestCount": pending},
        "messages": [{"text": "private conversation"}],
    }


class MonitorTest(unittest.TestCase):
    def run_monitor(self, states, *args):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "states").write_text(json.dumps(states))
            stub = root / "t3"
            stub.write_text(f"#!{sys.executable}\n" + """\
import json, sys
from pathlib import Path
assert sys.argv[1:] == ["thread", "show", "--json", "--messages", "0", "--", "test-thread"]
path = Path(__file__).with_name("states")
first, *rest = json.loads(path.read_text())
path.write_text(json.dumps(rest))
if first is None:
    sys.exit("server unavailable")
print(json.dumps(first))
""")
            stub.chmod(0o700)
            sleep = root / "sleep"
            sleep.write_text('#!/usr/bin/env bash\n[[ "$1" == 2 ]]\n')
            sleep.chmod(0o700)
            return subprocess.run(
                ["bash", SCRIPT, *args],
                env=dict(os.environ, PATH=f"{root}:{os.environ['PATH']}"),
                capture_output=True, text=True, timeout=5,
            )

    def test_polling_reports_changes_but_not_conversation(self):
        result = self.run_monitor(
            [response("running"), response("running"), response("waiting", 1),
             response("waiting", 0), response("completed")],
            "--interval", "2", THREAD,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [line.split(" ", 1)[1] for line in result.stdout.splitlines()],
            [f"{THREAD} {state} (pending requests: {pending})"
             for state, pending in [("running", 0), ("waiting", 1), ("waiting", 0), ("completed", 0)]],
        )

    def test_unsuccessful_terminal_states(self):
        for status in ("interrupted", "failed", "cancelled", "rolled_back"):
            with self.subTest(status=status):
                result = self.run_monitor([response(status)], THREAD)
                self.assertEqual(result.returncode, 1)
                self.assertIn(f" {THREAD} {status} ", result.stdout)

    def test_read_errors(self):
        for reply in (None, {"thread": {"status": "completed"}}):
            with self.subTest(reply=reply):
                result = self.run_monitor([reply], THREAD)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, "")
                self.assertIn("could not read status", result.stderr)

    def test_invalid_usage(self):
        for args in ([], ["--interval", "0", THREAD], ["--interval"], [THREAD, THREAD]):
            with self.subTest(args=args):
                self.assertEqual(self.run_monitor([], *args).returncode, 2)


if __name__ == "__main__":
    unittest.main()
