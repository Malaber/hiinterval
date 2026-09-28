#!/usr/bin/env python3
"""Validate and bundle CI marketing screenshots for App Store Connect.

Install Pillow before running: ``python3 -m pip install Pillow``.
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import zipfile
from pathlib import Path
from typing import Mapping

from PIL import Image, UnidentifiedImageError


ALLOWED_SIZES: dict[str, frozenset[tuple[int, int]]] = {
    "iPhone": frozenset({(1260, 2736), (1290, 2796), (1320, 2868)}),
    "iPad": frozenset({(2064, 2752), (2048, 2732)}),
}
ARTIFACT_NAME = re.compile(r"^app-store-screenshots-(iPhone|iPad)-[^/]+$")
VERSION = re.compile(r"^\d+\.\d+\.\d+$")
COMMIT = re.compile(r"^[0-9a-fA-F]{7,64}$")


class PackagingError(ValueError):
    """Downloaded screenshot artifacts cannot form a complete release bundle."""


def _artifact_files(input_dir: Path) -> dict[str, dict[str, Path]]:
    files: dict[str, dict[str, Path]] = {"iPhone": {}, "iPad": {}}
    artifacts = sorted(
        path for path in input_dir.rglob("app-store-screenshots-*")
        if path.is_dir() and ARTIFACT_NAME.fullmatch(path.name)
    )
    if not artifacts:
        raise PackagingError("No app-store-screenshots-iPhone/iPad artifacts found")

    for artifact in artifacts:
        family = ARTIFACT_NAME.fullmatch(artifact.name).group(1)  # type: ignore[union-attr]
        # upload-artifact strips the uploaded `marketing/` root on download.
        # Accept both downloaded artifacts and direct local runner output.
        locale_dir = artifact / "en-US"
        if not locale_dir.is_dir():
            locale_dir = artifact / "marketing" / "en-US"
        if not locale_dir.is_dir():
            raise PackagingError(f"Missing en-US screenshot directory: {artifact}")
        screenshots = sorted(locale_dir.glob("*.png"))
        if not screenshots:
            raise PackagingError(f"No PNG screenshots: {locale_dir}")
        for screenshot in screenshots:
            if screenshot.name in files[family]:
                raise PackagingError(
                    f"Duplicate {family} screenshot {screenshot.name}: "
                    f"{files[family][screenshot.name]} and {screenshot}"
                )
            files[family][screenshot.name] = screenshot
    return files


def _rgb_png(path: Path, family: str, allowed_sizes: Mapping[str, frozenset[tuple[int, int]]]) -> tuple[bytes, tuple[int, int]]:
    try:
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG":
                raise PackagingError(f"Not a PNG image: {path}")
            if image.size not in allowed_sizes[family]:
                expected = ", ".join(f"{w}x{h}" for w, h in sorted(allowed_sizes[family]))
                raise PackagingError(
                    f"Unsupported {family} size {image.width}x{image.height}: {path}; "
                    f"expected {expected}"
                )
            # Flatten transparency before upload; the App Store expects opaque artwork.
            rgb = Image.new("RGB", image.size, (255, 255, 255))
            if "A" in image.getbands() or "transparency" in image.info:
                rgba = image.convert("RGBA")
                rgb.paste(rgba, mask=rgba.getchannel("A"))
            else:
                rgb.paste(image.convert("RGB"))
            output = io.BytesIO()
            rgb.save(output, format="PNG", optimize=True)
            return output.getvalue(), image.size
    except (OSError, UnidentifiedImageError) as error:
        raise PackagingError(f"Cannot decode screenshot {path}: {error}") from error


def package_screenshots(
    input_dir: Path,
    output_zip: Path,
    version: str,
    commit: str,
    *,
    allowed_sizes: Mapping[str, frozenset[tuple[int, int]]] = ALLOWED_SIZES,
) -> dict:
    """Write validated, opaque PNGs and source manifest into a ZIP."""
    if not input_dir.is_dir():
        raise PackagingError(f"Input directory does not exist: {input_dir}")
    if not VERSION.fullmatch(version):
        raise PackagingError(f"Invalid marketing version: {version}")
    if not COMMIT.fullmatch(commit):
        raise PackagingError(f"Invalid commit SHA: {commit}")

    files = _artifact_files(input_dir)
    names = set(files["iPhone"])
    if not 1 <= len(names) <= 10:
        raise PackagingError(f"Expected 1-10 iPhone screenshots, found {len(names)}")
    if names != set(files["iPad"]):
        only_phone = sorted(names - set(files["iPad"]))
        only_pad = sorted(set(files["iPad"]) - names)
        raise PackagingError(
            f"iPhone/iPad screenshot sets differ; iPhone only: {only_phone}; "
            f"iPad only: {only_pad}"
        )

    manifest: dict = {
        "version": version,
        "sourceCommit": commit.lower(),
        "locale": "en-US",
        "screenshots": {"iPhone": [], "iPad": []},
    }
    encoded: dict[str, bytes] = {}
    for family in ("iPhone", "iPad"):
        for name in sorted(names):
            png, (width, height) = _rgb_png(files[family][name], family, allowed_sizes)
            archive_path = f"{family}/en-US/{name}"
            encoded[archive_path] = png
            manifest["screenshots"][family].append(
                {"file": archive_path, "width": width, "height": height}
            )

    output_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for archive_path, png in encoded.items():
            bundle.writestr(archive_path, png)
        bundle.writestr("manifest.json", json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Downloaded CI artifacts directory")
    parser.add_argument("--output", type=Path, required=True, help="Destination ZIP file")
    parser.add_argument("--version", required=True, help="App marketing version, e.g. 0.5.4")
    parser.add_argument("--commit", required=True, help="Git source commit SHA")
    args = parser.parse_args(argv)
    try:
        manifest = package_screenshots(args.input, args.output, args.version, args.commit)
    except PackagingError as error:
        parser.error(str(error))
    print(f"Packaged {len(manifest['screenshots']['iPhone'])} screenshots per device: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
