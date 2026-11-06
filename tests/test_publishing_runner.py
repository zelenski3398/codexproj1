"""Exercise CI failure propagation without needing a Godot installation."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PublishingRunnerChecks(unittest.TestCase):
    def invoke(self, body, timeout=5):
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / 'fake-godot'
            executable.write_text('#!' + sys.executable + '\n' + body)
            executable.chmod(0o755)
            output = Path(temporary) / 'results'
            environment = os.environ.copy()
            environment['GODOT_BIN'] = str(executable)
            environment['GITHUB_ACTIONS'] = 'true'
            environment['GITHUB_STEP_SUMMARY'] = str(Path(temporary) / 'github-summary.md')
            result = subprocess.run(
                [sys.executable, str(ROOT / 'tools/run_godot_checks.py'),
                 '--only', 'weapons_checks', '--timeout', str(timeout),
                 '--output-dir', str(output)],
                env=environment, capture_output=True, text=True, timeout=15)
            report = json.loads((output / 'results.json').read_text())[0]
            self.assertTrue((output / report['log']).exists())
            self.assertTrue((output / 'summary.md').exists())
            self.assertEqual((Path(temporary) / 'github-summary.md').read_text(), (output / 'summary.md').read_text())
            return result, report

    def test_valid_suite_is_green(self):
        result, report = self.invoke("print('FAILURE AI RESULT: 8/8 passed')\n")
        self.assertEqual(result.returncode, 0)
        self.assertTrue(report['passed'])

    def test_nonzero_failure_is_not_hidden(self):
        result, report = self.invoke('raise SystemExit(9)\n')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report['exit_code'], 9)
        self.assertIn('::error file=tests/weapons_checks.gd::', result.stdout)
        self.assertFalse(report['passed'])

    def test_script_error_with_zero_engine_exit_is_red(self):
        result, report = self.invoke("print('SCRIPT ERROR: invalid method')\n")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report['exit_code'], 0)
        self.assertFalse(report['passed'])

    def test_timeout_is_red_and_preserves_report(self):
        result, report = self.invoke('import time\ntime.sleep(30)\n', timeout=.1)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report['exit_code'], 124)


if __name__ == '__main__':
    unittest.main()
