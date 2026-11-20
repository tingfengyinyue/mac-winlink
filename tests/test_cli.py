import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'bin' / 'winlink'


class ClientTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='winlink tests ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'config with spaces'
        self.sshconfig = self.root / 'ssh' / 'config'
        self.tools = self.root / 'tools'
        self.tools.mkdir()
        self.capture = self.root / 'arguments.json'
        for name in ('ssh', 'code'):
            tool = self.tools / name
            tool.write_text('#!/usr/bin/env python3\nimport os,sys,json\n'
                            'json.dump(sys.argv[1:],open(os.environ["CAPTURE"],"w"))\n'
                            'sys.exit(int(os.environ.get("REMOTE_STATUS","0")))\n')
            tool.chmod(0o755)
        self.env = dict(os.environ, WINLINK_HOME=str(self.config),
                        WINLINK_SSH_CONFIG=str(self.sshconfig), CAPTURE=str(self.capture),
                        PATH=str(self.tools) + os.pathsep + os.environ['PATH'])

    def run_cli(self, *args, status=0, input=None):
        self.assertTrue(CLI.is_file(), 'winlink CLI has not been implemented')
        result = subprocess.run(['/bin/bash', str(CLI), *args], env=self.env,
                                input=input, text=True, capture_output=True)
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        return result

    def add_target(self):
        return self.run_cli('add', 'lab', '--host', '192.0.2.50', '--user', 'tester',
                            '--port', '2222', '--workdir', "C:\\测试 项目\\O'Brien")

    def captured(self):
        return json.loads(self.capture.read_text())

    def test_add_creates_valid_openssh_config_and_preserves_existing_config(self):
        self.sshconfig.parent.mkdir()
        original = 'Host *\n    ServerAliveInterval 60\n'
        self.sshconfig.write_text(original)
        self.add_target()
        result = subprocess.run(['/usr/bin/ssh', '-G', '-F', str(self.sshconfig), 'winlink-lab'],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('hostname 192.0.2.50\n', result.stdout)
        self.assertIn('user tester\n', result.stdout)
        self.assertIn('port 2222\n', result.stdout)
        self.assertTrue(self.sshconfig.read_text().endswith(original))
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o700)

    def test_repeat_add_is_idempotent_and_list_shows_target(self):
        self.add_target()
        self.add_target()
        self.assertEqual(self.sshconfig.read_text().count('Include '), 1)
        self.assertIn('lab', self.run_cli('list').stdout)

    def test_exec_preserves_unicode_quotes_directory_and_remote_exit_code(self):
        self.add_target()
        script = 'Write-Output "你好 $env:OS"; exit 7'
        self.env['REMOTE_STATUS'] = '7'
        self.run_cli('exec', 'lab', '--', script, status=7)
        arguments = self.captured()
        self.assertIn('winlink-lab', arguments)
        remote = arguments[-1]
        encoded = remote.split('-EncodedCommand ', 1)[1]
        decoded = base64.b64decode(encoded).decode('utf-16le')
        self.assertIn("Set-Location -LiteralPath 'C:\\测试 项目\\O''Brien'", decoded)
        self.assertIn(script, decoded)

    def test_script_accepts_file_and_preserves_content(self):
        self.add_target()
        script = self.root / 'test job.ps1'
        script.write_text('Write-Output "多行"\nexit 3\n')
        self.run_cli('script', 'lab', str(script))
        encoded = self.captured()[-1].split('-EncodedCommand ', 1)[1]
        self.assertIn(script.read_text(), base64.b64decode(encoded).decode('utf-16le'))

    def test_shell_and_vscode_use_same_registered_host(self):
        self.add_target()
        self.run_cli('shell', 'lab')
        self.assertEqual(self.captured()[-1], 'winlink-lab')
        self.run_cli('code', 'lab', 'C:/work/demo')
        self.assertEqual(self.captured(), ['--remote', 'ssh-remote+winlink-lab', 'C:/work/demo'])

    def test_host_injection_and_invalid_alias_are_rejected(self):
        for alias, host in [('bad/name', '127.0.0.1'),
                            ('lab', '127.0.0.1\nProxyCommand touch /tmp/no'),
                            ('lab', '-oProxyCommand=whoami')]:
            with self.subTest(alias=alias, host=host):
                self.run_cli('add', alias, '--host', host, '--user', 'tester', status=2)
        self.assertFalse(self.sshconfig.exists())

    def test_unknown_host_does_not_execute_ssh(self):
        self.run_cli('exec', 'missing', '--', 'whoami', status=2)
        self.assertFalse(self.capture.exists())

    def test_remove_keeps_other_targets(self):
        self.add_target()
        self.run_cli('add', 'other', '--host', '198.51.100.20', '--user', 'dev')
        self.run_cli('remove', 'lab')
        self.assertNotIn('lab', self.run_cli('list').stdout)
        self.run_cli('shell', 'other')
        self.assertEqual(self.captured()[-1], 'winlink-other')

    def test_public_key_prints_only_public_material(self):
        self.config.mkdir()
        (self.config / 'id_ed25519').write_text('PRIVATE MARKER')
        (self.config / 'id_ed25519.pub').write_text('ssh-ed25519 public-test laptop\n')
        result = self.run_cli('pubkey')
        self.assertEqual(result.stdout, 'ssh-ed25519 public-test laptop\n')
        self.assertNotIn('PRIVATE', result.stdout)

    def test_original_global_options_still_apply_to_unrelated_hosts(self):
        self.sshconfig.parent.mkdir()
        self.sshconfig.write_text('ServerAliveInterval 71\nHost unrelated\n    HostName 198.51.100.30\n')
        self.add_target()
        result = subprocess.run(['/usr/bin/ssh', '-G', '-F', str(self.sshconfig), 'unrelated'],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('serveraliveinterval 71\n', result.stdout)

    def test_invalid_port_and_multiline_workdir_are_rejected_before_config_changes(self):
        for extra in [('--port', '0'), ('--port', '65536'), ('--port', 'x'),
                      ('--workdir', 'C:\\work\nexit 9')]:
            self.run_cli('add', 'lab', '--host', '192.0.2.10', '--user', 'dev', *extra, status=2)
        self.assertFalse(self.sshconfig.exists())

    def test_long_script_fails_before_opening_connection(self):
        self.add_target()
        self.run_cli('exec', 'lab', '--', 'Write-Output "' + 'x' * 8000 + '"', status=2)
        self.assertFalse(self.capture.exists())

    def test_installer_can_install_into_a_path_with_spaces(self):
        destination = self.root / 'installed tools'
        env = dict(self.env, WINLINK_BIN_DIR=str(destination))
        result = subprocess.run(['/bin/bash', str(ROOT / 'install-mac.sh')],
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        installed = destination / 'winlink'
        self.assertTrue(os.access(installed, os.X_OK))
        result = subprocess.run([str(installed), '--help'], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PowerShell', result.stdout)


if __name__ == '__main__':
    unittest.main()
