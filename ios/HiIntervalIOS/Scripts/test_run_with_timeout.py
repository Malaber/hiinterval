"""Tests for the CI command timeout wrapper."""

import subprocess
import sys
import unittest
from pathlib import Path


WRAPPER = Path(__file__).with_name("run_with_timeout.py")


class RunWithTimeoutTests(unittest.TestCase):
    def run_wrapper(self, seconds: str, script: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(WRAPPER), seconds, sys.executable, "-c", script],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
        )

    def test_success_forwards_output(self) -> None:
        result = self.run_wrapper("3", "print('ready')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "ready")

    def test_nonzero_exit_is_preserved(self) -> None:
        result = self.run_wrapper("3", "import sys; sys.exit(23)")
        self.assertEqual(result.returncode, 23)

    def test_timeout_reports_error_and_stops_child(self) -> None:
        result = self.run_wrapper("0.1", "import time; time.sleep(30)")
        self.assertEqual(result.returncode, 124)
        self.assertIn("::error::Command exceeded 0.1s wall-clock limit", result.stderr)


if __name__ == "__main__":
    unittest.main()
