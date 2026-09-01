#!/usr/bin/env python3
"""Off-site backup storage on Cloudflare R2 (S3-compatible).

Credentials come exclusively from the environment, which on Fly means encrypted
secrets. Nothing here reads a config file, takes a credential argument, or
prints a secret -- so a backup running with `set -x` still cannot leak one.

Commands:
  upload <path>...        upload files under the configured prefix
  list                    list stored backups, newest first
  download <key> <dest>   fetch one object
  prune  [--keep N]       delete all but the N newest archives
"""

from __future__ import annotations

import argparse
import os
import sys

try:
    import boto3
    from botocore.config import Config
    from botocore.exceptions import BotoCoreError, ClientError
except ImportError:  # pragma: no cover
    print("boto3 is not installed in this image", file=sys.stderr)
    sys.exit(3)

REQUIRED = ("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET")


def client_and_bucket():
    missing = [name for name in REQUIRED if not os.environ.get(name)]
    if missing:
        # Names only -- never values.
        print(f"R2 is not configured; missing: {', '.join(missing)}", file=sys.stderr)
        sys.exit(2)

    account = os.environ["R2_ACCOUNT_ID"]
    session = boto3.session.Session()
    client = session.client(
        "s3",
        endpoint_url=f"https://{account}.r2.cloudflarestorage.com",
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
        config=Config(
            retries={"max_attempts": 5, "mode": "standard"},
            # Large archives: fail slowly rather than spuriously.
            connect_timeout=30,
            read_timeout=300,
        ),
    )
    return client, os.environ["R2_BUCKET"]


def prefix() -> str:
    value = os.environ.get("R2_PREFIX", "mythic-prehistory").strip("/")
    return f"{value}/" if value else ""


def cmd_upload(args) -> int:
    client, bucket = client_and_bucket()
    for path in args.paths:
        if not os.path.isfile(path):
            print(f"not a file: {path}", file=sys.stderr)
            return 1
        key = f"{prefix()}{os.path.basename(path)}"
        size = os.path.getsize(path)
        try:
            # upload_file handles multipart automatically for large archives.
            client.upload_file(path, bucket, key)
        except (BotoCoreError, ClientError) as exc:
            print(f"upload failed for {key}: {exc}", file=sys.stderr)
            return 1
        print(f"uploaded {key} ({size} bytes)")
    return 0


def _list_objects(client, bucket):
    paginator = client.get_paginator("list_objects_v2")
    objects = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix()):
        objects.extend(page.get("Contents", []))
    objects.sort(key=lambda o: o["LastModified"], reverse=True)
    return objects


def cmd_list(args) -> int:
    client, bucket = client_and_bucket()
    try:
        objects = _list_objects(client, bucket)
    except (BotoCoreError, ClientError) as exc:
        print(f"list failed: {exc}", file=sys.stderr)
        return 1
    if not objects:
        print("(no off-site backups found)")
        return 0
    for obj in objects:
        mib = obj["Size"] / (1024 * 1024)
        stamp = obj["LastModified"].strftime("%Y-%m-%d %H:%M:%SZ")
        print(f"{stamp}  {mib:9.1f} MiB  {obj['Key']}")
    return 0


def cmd_download(args) -> int:
    client, bucket = client_and_bucket()
    try:
        client.download_file(bucket, args.key, args.dest)
    except (BotoCoreError, ClientError) as exc:
        print(f"download failed: {exc}", file=sys.stderr)
        return 1
    print(f"downloaded {args.key} -> {args.dest}")
    return 0


def cmd_prune(args) -> int:
    client, bucket = client_and_bucket()
    try:
        objects = _list_objects(client, bucket)
    except (BotoCoreError, ClientError) as exc:
        print(f"list failed: {exc}", file=sys.stderr)
        return 1

    archives = [o for o in objects if o["Key"].endswith(".tar.zst")]
    doomed = archives[args.keep:]
    if not doomed:
        print(f"nothing to prune ({len(archives)} archives, keeping {args.keep})")
        return 0

    for obj in doomed:
        key = obj["Key"]
        try:
            client.delete_object(Bucket=bucket, Key=key)
            client.delete_object(Bucket=bucket, Key=f"{key}.json")
        except (BotoCoreError, ClientError) as exc:
            print(f"prune failed for {key}: {exc}", file=sys.stderr)
            return 1
        print(f"pruned {key}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="R2 backup storage")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_up = sub.add_parser("upload")
    p_up.add_argument("paths", nargs="+")
    p_up.set_defaults(func=cmd_upload)

    sub.add_parser("list").set_defaults(func=cmd_list)

    p_dl = sub.add_parser("download")
    p_dl.add_argument("key")
    p_dl.add_argument("dest")
    p_dl.set_defaults(func=cmd_download)

    p_pr = sub.add_parser("prune")
    p_pr.add_argument("--keep", type=int, default=int(os.environ.get("R2_KEEP", "30")))
    p_pr.set_defaults(func=cmd_prune)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
