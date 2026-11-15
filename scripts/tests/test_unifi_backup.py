import http.server
import json
import ssl
import subprocess
import sys
import tempfile
import threading
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from unifi_backup import AzureStore, SystemController, backups_to_delete, store_backup


class Controller:
    def download(self, path):
        path.write_bytes(b"simulated UniFi backup")


class Store:
    def __init__(self, corrupt=False):
        self.blobs = {}
        self.verified = set()
        self.corrupt = corrupt

    def upload(self, name, path):
        self.blobs[name] = path.read_bytes()

    def download(self, name, path):
        path.write_bytes(b"wrong" if self.corrupt else self.blobs[name])

    def mark_verified(self, name, digest):
        self.verified.add(name)


class BackupTests(unittest.TestCase):
    def test_backup_is_verified_only_after_readback_matches(self):
        store = Store()
        with tempfile.TemporaryDirectory() as workdir:
            store_backup(Controller(), store, "test.unifi", Path(workdir))
            self.assertEqual(store.blobs["test.unifi"], b"simulated UniFi backup")
            self.assertEqual(store.verified, {"test.unifi"})

    def test_corrupt_readback_fails_without_marking_backup_verified(self):
        store = Store(corrupt=True)
        with tempfile.TemporaryDirectory() as workdir:
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                store_backup(Controller(), store, "test.unifi", Path(workdir))
            self.assertEqual(store.verified, set())

    def test_empty_backup_is_not_uploaded(self):
        class EmptyController:
            def download(self, path):
                path.write_bytes(b"")

        store = Store()
        with tempfile.TemporaryDirectory() as workdir:
            with self.assertRaisesRegex(ValueError, "empty"):
                store_backup(EmptyController(), store, "test.unifi", Path(workdir))
            self.assertEqual(store.blobs, {})


class ControllerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        directory = Path(cls.temp.name)
        cls.cert = directory / "cert.pem"
        key = directory / "key.pem"
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
             "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
             "-keyout", str(key), "-out", str(cls.cert)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, format, *args):
                pass

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                if self.path != "/api/auth/login" or body != {"username": "user", "password": "password"}:
                    self.send_error(403)
                    return
                self.send_response(200)
                self.send_header("Set-Cookie", "TOKEN=session; Path=/")
                self.end_headers()

            def do_GET(self):
                if self.path != "/api/backup/download" or self.headers.get("Cookie") != "TOKEN=session":
                    self.send_error(403)
                    return
                self.send_response(200)
                self.send_header("Content-Type", self.server.backup_type)
                self.end_headers()
                self.wfile.write(self.server.backup_data)

        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cls.cert, key)
        cls.server.socket = context.wrap_socket(cls.server.socket, server_side=True)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
        cls.temp.cleanup()

    def test_controller_downloads_binary_backup_over_verified_tls(self):
        self.server.backup_type = "application/octet-stream"
        self.server.backup_data = b"example backup bytes"
        client = SystemController(
            f"https://localhost:{self.server.server_port}", "user", "password", self.cert.read_text()
        )
        with tempfile.TemporaryDirectory() as workdir:
            path = Path(workdir) / "backup"
            client.download(path)
            self.assertEqual(path.read_bytes(), b"example backup bytes")

    def test_controller_rejects_html_error_response(self):
        self.server.backup_type = "text/html"
        self.server.backup_data = b"login page"
        client = SystemController(
            f"https://localhost:{self.server.server_port}", "user", "password", self.cert.read_text()
        )
        with tempfile.TemporaryDirectory() as workdir:
            with self.assertRaisesRegex(ValueError, "unexpected backup response"):
                client.download(Path(workdir) / "backup")

    def test_controller_rejects_certificate_for_wrong_hostname(self):
        client = SystemController(
            f"https://127.0.0.1:{self.server.server_port}", "user", "password", self.cert.read_text()
        )
        with tempfile.TemporaryDirectory() as workdir:
            with self.assertRaises(OSError):
                client.download(Path(workdir) / "backup")


class RetentionTests(unittest.TestCase):
    def test_retains_newest_twenty_even_when_old(self):
        records = [
            {"name": str(day), "created": datetime(2026, 1, day, tzinfo=timezone.utc)}
            for day in range(1, 23)
        ]
        result = backups_to_delete(records, datetime(2026, 11, 15, tzinfo=timezone.utc))
        self.assertEqual([item["name"] for item in result], ["2", "1"])

    def test_keeps_recent_backups_even_when_outside_newest_twenty(self):
        records = [
            {"name": str(day), "created": datetime(2026, 11, day, tzinfo=timezone.utc)}
            for day in range(1, 23)
        ]
        result = backups_to_delete(records, datetime(2026, 11, 30, tzinfo=timezone.utc))
        self.assertEqual(result, [])

    def test_retains_backup_exactly_at_ninety_day_cutoff(self):
        now = datetime(2026, 11, 15, tzinfo=timezone.utc)
        records = [{"name": "cutoff", "created": datetime(2026, 8, 17, tzinfo=timezone.utc)}]
        records.extend(
            {"name": str(day), "created": datetime(2026, 11, day, tzinfo=timezone.utc)}
            for day in range(1, 22)
        )
        self.assertEqual(backups_to_delete(records, now), [])

    def test_cleanup_deletes_only_old_verified_matching_blobs(self):
        class SimulatedAzure(AzureStore):
            def __init__(self):
                super().__init__("testaccount")
                self.blobs = [
                    {
                        "name": f"unifi-system/202601{day:02d}T000000Z-{day:032x}.unifi",
                        "metadata": {"verified": "true", "sha256": "a" * 64},
                        "properties": {"etag": str(day)},
                    }
                    for day in range(1, 23)
                ]
                self.blobs.append({
                    "name": "unifi-system/unverified.unifi",
                    "metadata": {},
                    "properties": {"etag": "other"},
                })

            def command(self, *args):
                if args[0] == "list":
                    return self.blobs
                if args[0] == "delete":
                    name = args[args.index("--name") + 1]
                    etag = args[args.index("--if-match") + 1]
                    self.blobs = [b for b in self.blobs if not (b["name"] == name and b["properties"]["etag"] == etag)]
                    return None
                raise AssertionError(args)

        store = SimulatedAzure()
        store.prune(datetime(2026, 11, 15, tzinfo=timezone.utc))
        self.assertEqual(len(store.blobs), 21)
        self.assertEqual(store.blobs[-1]["name"], "unifi-system/unverified.unifi")


if __name__ == "__main__":
    unittest.main()
