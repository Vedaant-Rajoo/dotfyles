"""Exercise the real reader against an isolated Codex app-server fixture."""

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request


if sys.argv[-1:] == ["--fake-codex"]:
    Path(os.environ["CALLS"]).open("a").write("called\n")
    Path(os.environ["CHILD_PID"]).write_text(str(os.getpid()))
    for line in sys.stdin:
        request = json.loads(line)
        if "id" not in request:
            continue
        if request["method"] == "initialize":
            result = {"result": {"userAgent": "fixture"}}
        else:
            if os.environ.get("STALL"):
                time.sleep(10)
            result = json.loads(os.environ["RESPONSE"])
        print(json.dumps({"id": request["id"], **result}), flush=True)
    sys.exit(0)


ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader("quota", str(ROOT / "bin/t3-codex-quota"))
spec = importlib.util.spec_from_loader(loader.name, loader)
quota = importlib.util.module_from_spec(spec)
loader.exec_module(quota)


def response(primary=None, secondary=None):
    return {"result": {"rateLimits": {
        "limitId": "codex", "primary": primary, "secondary": secondary,
        "accountId": "private-account", "credits": {"balance": "private-balance"},
    }}}


WEEKLY = {"usedPercent": 47, "windowDurationMins": 10080, "resetsAt": 1900000000}


class QuotaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        binary = self.root / "codex"
        binary.write_text("#!" + sys.executable + "\nimport os\nos.execv(" + repr(sys.executable)
                          + ", [" + repr(sys.executable) + ", " + repr(str(Path(__file__).resolve()))
                          + ", '--fake-codex'])\n")
        binary.chmod(0o700)
        self.env = patch.dict(os.environ, {
            "HOME": str(self.root), "CODEX_HOME": str(self.root / ".codex"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "PATH": str(self.root), "RESPONSE": json.dumps(response(WEEKLY)),
            "CALLS": str(self.root / "calls"), "CHILD_PID": str(self.root / "child"),
        }, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def assert_child_stopped(self):
        pid = int((self.root / "child").read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def test_weekly_primary_uses_duration_and_omits_private_fields(self):
        feed = quota.read_quota()
        account = feed["accounts"][0]
        self.assertEqual(account["providerInstanceId"], "codex")
        self.assertEqual(account["windows"], [{
            "id": "primary", "kind": "weekly", "label": "Weekly",
            "usedPercent": 47, "resetsAt": "2030-03-17T17:46:40Z",
        }])
        self.assertNotIn("private-", json.dumps(feed))
        self.assert_child_stopped()

    def test_session_and_secondary_weekly(self):
        session = {"usedPercent": 12, "windowDurationMins": 300}
        os.environ["RESPONSE"] = json.dumps(response(session, WEEKLY))
        windows = quota.read_quota()["accounts"][0]["windows"]
        self.assertEqual([(w["kind"], w["usedPercent"]) for w in windows],
                         [("session", 12), ("weekly", 47)])

    def test_error_and_empty_quota_fail_without_leaking_upstream_message(self):
        for payload in [{"error": {"message": "private-token"}}, response()]:
            os.environ["RESPONSE"] = json.dumps(payload)
            with self.assertRaises(RuntimeError) as caught:
                quota.read_quota()
            self.assertNotIn("private-token", str(caught.exception))
            self.assert_child_stopped()

    def test_timeout_reaps_child(self):
        os.environ["STALL"] = "1"
        with patch.object(quota, "RPC_TIMEOUT", 0.3):
            with self.assertRaises(TimeoutError):
                quota.read_quota()
        self.assert_child_stopped()

    def test_invalid_percentage_is_not_reported_as_zero(self):
        for bad in [True, "47", -1, float("nan"), float("inf")]:
            os.environ["RESPONSE"] = json.dumps(response({**WEEKLY, "usedPercent": bad}))
            with self.assertRaises(RuntimeError):
                quota.read_quota()

    def test_invalid_reset_time_fails(self):
        for bad in [True, -1, 253402300800, "tomorrow"]:
            os.environ["RESPONSE"] = json.dumps(response({**WEEKLY, "resetsAt": bad}))
            with self.assertRaises(RuntimeError):
                quota.read_quota()

    def test_authorization_cache_and_expired_failure(self):
        server = quota.make_server(b"fixture-secret", 0)
        self.addCleanup(server.server_close)

        def get(path="/quota", token="fixture-secret"):
            thread = threading.Thread(target=server.handle_request)
            thread.start()
            request = urllib.request.Request(
                "http://127.0.0.1:%d%s" % (server.server_port, path),
                headers={"Authorization": "Bearer " + token},
            )
            try:
                with urllib.request.urlopen(request, timeout=3) as result:
                    return result.status, json.load(result)
            except urllib.error.HTTPError as error:
                return error.code, json.load(error)
            finally:
                thread.join(timeout=3)
                self.assertFalse(thread.is_alive())

        self.assertEqual(get(token="wrong")[0], 401)
        self.assertFalse((self.root / "calls").exists())
        self.assertEqual(get(path="/v1/responses")[0], 404)
        self.assertEqual(get()[0], 200)
        self.assertEqual(get()[0], 200)
        self.assertEqual((self.root / "calls").read_text().splitlines(), ["called"])
        server.expires_at = 0
        os.environ["RESPONSE"] = json.dumps({"error": {"message": "private-token"}})
        status, body = get()
        self.assertEqual(status, 503)
        self.assertNotIn("private-token", json.dumps(body))
        self.assertNotIn("accounts", body)


if __name__ == "__main__":
    unittest.main()
