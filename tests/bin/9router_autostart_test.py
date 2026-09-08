"""Exercise login configuration in an isolated directory, never live launchd."""

from contextlib import redirect_stdout
import io
from pathlib import Path
import plistlib
import runpy
import tempfile
import unittest
from unittest.mock import patch


install = runpy.run_path(
    str(Path(__file__).resolve().parents[2] / "bin/9router_autostart")
)["install"]


class AutostartTest(unittest.TestCase):
    def test_replaces_vendor_config_and_is_idempotent(self):
        with tempfile.TemporaryDirectory(prefix="9router-test-") as directory:
            user_home = Path(directory) / "User & Name"
            router = user_home / ".node_modules/lib/node_modules/9router/cli.js"
            router.parent.mkdir(parents=True)
            router.touch()
            target = user_home / "Library/LaunchAgents/com.9router.autostart.plist"
            target.parent.mkdir(parents=True)
            target.write_bytes(plistlib.dumps({"ProgramArguments": ["old-node"]}))
            runtime = "/runtime with spaces & symbols/bin/node"
            with (
                patch("sys.platform", "darwin"),
                patch("pathlib.Path.home", return_value=user_home),
                patch("shutil.which", return_value="/shim/node"),
                patch("subprocess.check_output", return_value=runtime + "\n") as execute,
                redirect_stdout(io.StringIO()),
            ):
                install()
                settings = plistlib.loads(target.read_bytes())
                self.assertEqual(settings["ProgramArguments"], [
                    runtime, str(router), "--tray", "--skip-update", "--no-browser",
                    "--host", "127.0.0.1", "--port", "20128",
                ])
                self.assertEqual(settings["Label"], "com.9router.autostart")
                self.assertTrue(settings["RunAtLoad"])
                self.assertFalse(settings["KeepAlive"])
                self.assertEqual(target.stat().st_mode & 0o777, 0o644)
                first_mtime = target.stat().st_mtime_ns
                install()
                self.assertEqual(target.stat().st_mtime_ns, first_mtime)
                # The only subprocess resolves Node; setup never starts a service.
                for call in execute.call_args_list:
                    self.assertEqual(call.args[0], ["/shim/node", "-p", "process.execPath"])

    def test_missing_dependencies_leave_existing_config_intact(self):
        with tempfile.TemporaryDirectory(prefix="9router-test-") as directory:
            user_home = Path(directory)
            target = user_home / "Library/LaunchAgents/com.9router.autostart.plist"
            target.parent.mkdir(parents=True)
            target.write_text("existing startup configuration")
            with (
                patch("sys.platform", "darwin"),
                patch("pathlib.Path.home", return_value=user_home),
                patch("shutil.which", return_value=None),
            ):
                with self.assertRaisesRegex(RuntimeError, "install Node"):
                    install()
            self.assertEqual(target.read_text(), "existing startup configuration")


if __name__ == "__main__":
    unittest.main()
