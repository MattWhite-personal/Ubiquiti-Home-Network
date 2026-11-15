"""Store a UniFi OS system backup in Azure without publishing it as an artifact."""

import argparse
import http.cookiejar
import hashlib
import json
import os
import re
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


PREFIX = "unifi-system/"
CONTAINER = "unifi-backups"
NAME_PATTERN = re.compile(r"^unifi-system/(\d{8}T\d{6}Z)-[0-9a-f]{32}\.unifi$")


def backups_to_delete(records, now):
    ordered = sorted(records, key=lambda record: (record["created"], record["name"]), reverse=True)
    return [record for record in ordered[20:] if record["created"] < now - timedelta(days=90)]


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def store_backup(controller, store, name, workdir):
    original = workdir / "backup"
    readback = workdir / "readback"
    controller.download(original)
    if not original.is_file() or original.stat().st_size == 0:
        raise ValueError("backup is empty")
    digest = file_hash(original)
    store.upload(name, original)
    store.download(name, readback)
    if file_hash(readback) != digest:
        raise ValueError("backup read-back hash mismatch")
    store.mark_verified(name, digest)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class SystemController:
    def __init__(self, base_url, username, password, ca_pem):
        parsed = urllib.parse.urlsplit(base_url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("UNIFI_BACKUP_URL must be an HTTPS URL without credentials")
        if parsed.path not in ("", "/") or parsed.query or parsed.fragment:
            raise ValueError("UNIFI_BACKUP_URL must not include a path, query, or fragment")
        self.base_url = base_url.rstrip("/")
        self.username = username
        self.password = password
        context = ssl.create_default_context(cadata=ca_pem)
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}),
            urllib.request.HTTPSHandler(context=context),
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
            NoRedirect(),
        )

    def download(self, destination):
        login = urllib.request.Request(
            self.base_url + "/api/auth/login",
            data=json.dumps({"username": self.username, "password": self.password}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with self.opener.open(login, timeout=30) as response:
            if response.status != 200:
                raise ValueError("UniFi login failed")
        request = urllib.request.Request(self.base_url + "/api/backup/download")
        with self.opener.open(request, timeout=300) as response:
            content_type = response.headers.get_content_type()
            if response.status != 200 or content_type not in {
                "application/octet-stream", "application/zip", "application/x-gzip",
                "application/gzip", "application/x-tar",
            }:
                raise ValueError("UniFi returned an unexpected backup response")
            with destination.open("xb") as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    output.write(chunk)


class AzureStore:
    def __init__(self, account):
        if not re.fullmatch(r"[a-z0-9]{3,24}", account):
            raise ValueError("invalid backup storage account name")
        self.account = account
        self.etags = {}

    def command(self, *args):
        command = [
            "az", "storage", "blob", *args, "--account-name", self.account,
            "--container-name", CONTAINER, "--auth-mode", "login",
            "--only-show-errors", "--output", "json",
        ]
        env = os.environ.copy()
        for key in ("AZURE_STORAGE_KEY", "AZURE_STORAGE_CONNECTION_STRING", "AZURE_STORAGE_SAS_TOKEN",
                    "AZURE_STORAGE_ACCOUNT", "AZURE_STORAGE_SERVICE_ENDPOINT"):
            env.pop(key, None)
        result = subprocess.run(command, capture_output=True, text=True, timeout=600, env=env)
        if result.returncode:
            raise RuntimeError(f"Azure blob {args[0]} failed (exit {result.returncode})")
        return json.loads(result.stdout) if result.stdout.strip() else None

    def upload(self, name, path):
        self.command("upload", "--name", name, "--file", str(path), "--if-none-match", "*")
        blob = self.command("show", "--name", name)
        self.etags[name] = blob["properties"]["etag"]

    def download(self, name, path):
        self.command("download", "--name", name, "--file", str(path), "--if-match", self.etags[name])

    def mark_verified(self, name, digest):
        self.command(
            "metadata", "update", "--name", name, "--if-match", self.etags[name],
            "--metadata", "verified=true", f"sha256={digest}",
        )

    def prune(self, now):
        blobs = self.command("list", "--prefix", PREFIX, "--include", "m", "--num-results", "*") or []
        records = []
        for blob in blobs:
            match = NAME_PATTERN.fullmatch(blob["name"])
            metadata = blob.get("metadata") or {}
            if not match or metadata.get("verified") != "true":
                continue
            if not re.fullmatch(r"[0-9a-f]{64}", metadata.get("sha256", "")):
                raise ValueError("verified backup has invalid metadata; cleanup stopped")
            created = datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
            records.append({"name": blob["name"], "created": created, "etag": blob["properties"]["etag"]})
        for record in backups_to_delete(records, now):
            self.command("delete", "--name", record["name"], "--if-match", record["etag"])


def required_env(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"{name} must be set")
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("backup", "backup-and-prune"))
    args = parser.parse_args()
    store = AzureStore(required_env("UNIFI_BACKUP_STORAGE_ACCOUNT"))
    controller = SystemController(
        required_env("UNIFI_BACKUP_URL"),
        required_env("UNIFI_BACKUP_USERNAME"),
        required_env("UNIFI_BACKUP_PASSWORD"),
        required_env("UNIFI_BACKUP_CA_PEM"),
    )
    now = datetime.now(timezone.utc)
    name = f"{PREFIX}{now:%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex}.unifi"
    with tempfile.TemporaryDirectory(prefix="unifi-backup-") as directory:
        store_backup(controller, store, name, Path(directory))
    print("UniFi system backup uploaded and read-back hash matched; restoreability is not verified.")
    if args.operation == "backup-and-prune":
        store.prune(datetime.now(timezone.utc))
        print("Backup retention cleanup completed.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, urllib.error.URLError) as exc:
        print(f"UniFi backup failed: {exc}", file=sys.stderr)
        sys.exit(1)
