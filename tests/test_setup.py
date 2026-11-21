import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SETUP = ROOT / 'setup.sh'


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='winlink setup ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'runtime'
        self.config.mkdir()
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '',
                        '-f', str(self.config / 'id_ed25519')], check=True)
        self.fingerprint = subprocess.check_output(
            ['ssh-keygen', '-lf', str(self.config / 'id_ed25519.pub')], text=True).split()[1]
        self.tools = self.root / 'tools'
        self.tools.mkdir()
        self.capture = self.root / 'ssh.json'
        ssh = self.tools / 'ssh'
        ssh.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                       'json.dump(sys.argv[1:],open(os.environ["CAPTURE"],"w"))\n'
                       'sys.exit(int(os.environ.get("SSH_STATUS","0")))\n')
        ssh.chmod(0o755)
        scan = self.tools / 'ssh-keyscan'
        scan.write_text('#!/usr/bin/env python3\nimport os,sys\n'
                        'port=sys.argv[sys.argv.index("-p")+1]\n'
                        'host=sys.argv[-1]\n'
                        'host=host if port=="22" else "["+host+"]:"+port\n'
                        'print(host+" "+open(os.environ["SCAN_PUB"]).read().strip())\n')
        scan.chmod(0o755)
        self.env = dict(os.environ, WINLINK_HOME=str(self.config),
                        WINLINK_BIN_DIR=str(self.root / 'bin'),
                        WINLINK_SSH_CONFIG=str(self.root / 'ssh' / 'config'),
                        WINLINK_KNOWN_HOSTS=str(self.root / 'ssh' / 'known_hosts'),
                        SCAN_PUB=str(self.config / 'id_ed25519.pub'), CAPTURE=str(self.capture),
                        PATH=str(self.tools) + os.pathsep + os.environ['PATH'])
        self.profile = self.root / 'office.winlink.json'

    def call(self, *args, status=0):
        self.assertTrue(SETUP.is_file(), 'Guided setup script is not implemented')
        result = subprocess.run(['/bin/bash', str(SETUP), *args], env=self.env,
                                cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, status, result.stdout + result.stderr)
        return result

    def connection(self, **changes):
        record = {'schemaVersion': 1, 'kind': 'winlink-connection', 'name': 'office',
                  'clientAddress': '192.0.2.50', 'clientKeyFingerprint': self.fingerprint,
                  'hostAddress': '192.0.2.10', 'hostFingerprint': self.fingerprint,
                  'user': 'tester', 'port': 2222}
        record.update(changes)
        self.profile.write_text(json.dumps(record))

    def test_prepare_exports_only_public_pairing_data(self):
        self.call('prepare', '--name', 'office', '--client-address', '192.0.2.50',
                  '--out', str(self.profile))
        data = json.loads(self.profile.read_text())
        self.assertEqual(data['kind'], 'winlink-request')
        self.assertEqual(data['clientAddress'], '192.0.2.50')
        self.assertEqual(data['clientKeyFingerprint'], self.fingerprint)
        self.assertEqual(data['publicKey'], (self.config / 'id_ed25519.pub').read_text().strip())
        self.assertNotIn('PRIVATE', self.profile.read_text())
        self.assertTrue((self.root / 'bin' / 'winlink').is_file())

    def test_connect_verifies_fingerprint_then_configures_and_checks_login(self):
        self.connection()
        self.call('connect', str(self.profile))
        host = (self.config / 'hosts' / 'office').read_text()
        self.assertIn('HostName 192.0.2.10', host)
        self.assertIn('Port 2222', host)
        self.assertIn('[192.0.2.10]:2222', Path(self.env['WINLINK_KNOWN_HOSTS']).read_text())
        args = json.loads(self.capture.read_text())
        self.assertIn('StrictHostKeyChecking=yes', args)
        self.assertIn('PasswordAuthentication=no', args)
        self.assertEqual(args[-2:], ['winlink-office', 'whoami'])

    def test_wrong_host_fingerprint_is_rejected_without_trusting_or_registering(self):
        self.connection(hostFingerprint='SHA256:' + 'A' * 43)
        self.call('connect', str(self.profile), status=2)
        self.assertFalse(Path(self.env['WINLINK_KNOWN_HOSTS']).exists())
        self.assertFalse((self.config / 'hosts' / 'office').exists())

    def test_other_macs_pairing_file_is_rejected(self):
        self.connection(clientKeyFingerprint='SHA256:' + 'B' * 43)
        self.call('connect', str(self.profile), status=2)
        self.assertFalse(self.capture.exists())

    def test_invalid_address_or_port_is_rejected_before_ssh(self):
        for changes in ({'hostAddress': '192.0.2.10\nProxyCommand whoami'}, {'port': 0},
                        {'hostAddress': '-oProxyCommand=whoami'}, {'port': 65536}):
            with self.subTest(changes=changes):
                self.connection(**changes)
                self.call('connect', str(self.profile), status=2)
        self.assertFalse(self.capture.exists())

    def test_repeated_connect_does_not_duplicate_host_trust(self):
        self.connection()
        self.call('connect', str(self.profile))
        before = Path(self.env['WINLINK_KNOWN_HOSTS']).read_text()
        self.call('connect', str(self.profile))
        self.assertEqual(before, Path(self.env['WINLINK_KNOWN_HOSTS']).read_text())

    def test_existing_conflicting_host_key_is_preserved_and_rejected(self):
        self.connection()
        other = self.root / 'other-key'
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(other)], check=True)
        known = Path(self.env['WINLINK_KNOWN_HOSTS'])
        known.parent.mkdir()
        original = '[192.0.2.10]:2222 ' + other.with_suffix('.pub').read_text()
        known.write_text(original)
        self.call('connect', str(self.profile), status=2)
        self.assertEqual(known.read_text(), original)

    def test_request_cannot_be_imported_as_finished_connection(self):
        self.connection(kind='winlink-request')
        self.call('connect', str(self.profile), status=2)

    def test_existing_other_key_algorithms_do_not_conflict_with_matching_ed25519(self):
        self.connection()
        other = self.root / 'ecdsa-host'
        subprocess.run(['ssh-keygen', '-q', '-t', 'ecdsa', '-N', '', '-f', str(other)], check=True)
        known = Path(self.env['WINLINK_KNOWN_HOSTS'])
        known.parent.mkdir()
        original = ('[192.0.2.10]:2222 ' + (self.config / 'id_ed25519.pub').read_text() +
                    '[192.0.2.10]:2222 ' + other.with_suffix('.pub').read_text())
        known.write_text(original)
        self.call('connect', str(self.profile))
        self.assertEqual(known.read_text(), original)

    def test_failed_login_returns_failure_and_keeps_diagnostics(self):
        self.connection()
        self.env['SSH_STATUS'] = '255'
        result = self.call('connect', str(self.profile), status=255)
        self.assertIn('office', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
