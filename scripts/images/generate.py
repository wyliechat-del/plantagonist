#!/usr/bin/env python3
"""Generate an image with Cloudflare Workers AI (Flux) for Plantagonist art.

Usage (from the repo root):
    python3 scripts/images/generate.py "a cartoon sunflower icon, flat colors"
    python3 scripts/images/generate.py "mossy stone texture" --name moss

Needs CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN, read from the shell or
from the repo's .env file. Writes art/generated/<name>.jpg plus a .json file
holding the prompt, steps and model.

Standard library only, so it runs on the Mac's built-in python3. Guide:
docs/images.md.
"""

import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "art" / "generated"
DEFAULT_MODEL = "@cf/black-forest-labs/flux-1-schnell"
API_BASE = os.environ.get("CLOUDFLARE_API_BASE", "https://api.cloudflare.com/client/v4")
MAX_STEPS = 8  # Flux Schnell's upper limit
MAX_PROMPT = 2048


def load_dotenv(path):
    """Fill os.environ from KEY=value lines, without overriding the shell."""
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key.strip(), value)


def slugify(text, limit=40):
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:limit].rstrip("-") or "image"


def parse_args(argv):
    p = argparse.ArgumentParser(description="Generate an image with Cloudflare Flux.")
    p.add_argument("prompt", help="what to draw, in plain words")
    p.add_argument("--name", help="file name without extension (default: from the prompt)")
    p.add_argument("--steps", type=int, default=4, help=f"1 to {MAX_STEPS}; more is slower and sharper (default 4)")
    p.add_argument("--model", default=DEFAULT_MODEL, help=f"Workers AI model (default {DEFAULT_MODEL})")
    p.add_argument("--out-dir", type=Path, default=OUT_DIR, help="folder to write to (default art/generated)")
    args = p.parse_args(argv)
    if not 1 <= args.steps <= MAX_STEPS:
        p.error(f"--steps must be 1 to {MAX_STEPS}")
    if len(args.prompt) > MAX_PROMPT:
        p.error(f"prompt is over {MAX_PROMPT} characters")
    return args


def run_model(account_id, token, model, payload):
    url = f"{API_BASE}/accounts/{account_id}/ai/run/{model}"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read()
    except urllib.error.HTTPError as err:
        detail = err.read().decode(errors="replace")[:500]
        hint = ""
        if err.code in (401, 403):
            hint = "\nCheck the token has the Workers AI permission and the account ID is right."
        sys.exit(f"Cloudflare returned HTTP {err.code}: {detail}{hint}")
    except urllib.error.URLError as err:
        sys.exit(f"Could not reach Cloudflare: {err.reason}")

    data = json.loads(body)
    image = (data.get("result") or {}).get("image")
    if not image:
        sys.exit(f"No image in the response: {body[:500]!r}")
    return base64.b64decode(image)


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])
    load_dotenv(REPO / ".env")
    account_id = os.environ.get("CLOUDFLARE_ACCOUNT_ID", "").strip()
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "").strip()
    missing = [n for n, v in (("CLOUDFLARE_ACCOUNT_ID", account_id), ("CLOUDFLARE_API_TOKEN", token)) if not v]
    if missing:
        sys.exit(f"Missing {', '.join(missing)}. Add the missing values to .env (see docs/images.md).")

    # Flux Schnell on Workers AI takes only prompt and steps; it rejects a seed.
    payload = {"prompt": args.prompt, "steps": args.steps}
    image = run_model(account_id, token, args.model, payload)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    name = args.name or slugify(args.prompt)
    out = args.out_dir / f"{name}.jpg"
    n = 2
    while out.exists():
        out = args.out_dir / f"{name}-{n}.jpg"
        n += 1
    out.write_bytes(image)
    meta = {
        "prompt": args.prompt,
        "steps": args.steps,
        "model": args.model,
        "created": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    out.with_suffix(".json").write_text(json.dumps(meta, indent=2) + "\n")
    shown = out.relative_to(REPO) if out.is_relative_to(REPO) else out
    print(f"Saved {shown}")


if __name__ == "__main__":
    main()
