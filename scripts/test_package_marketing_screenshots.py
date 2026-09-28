"""Focused validation of App Store screenshot packaging."""

from __future__ import annotations

import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from PIL import Image

from package_marketing_screenshots import PackagingError, package_screenshots


SMALL_SIZES = {"iPhone": frozenset({(12, 26)}), "iPad": frozenset({(20, 27)})}
COMMIT = "0123456789abcdef0123456789abcdef01234567"


class ScreenshotPackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "release.zip"

    def screenshot(
        self, family: str, name: str = "01-intro.png", *, shard: int = 0,
        size: tuple[int, int] | None = None, mode: str = "RGBA", direct: bool = True,
    ) -> Path:
        artifact = self.root / f"app-store-screenshots-{family}-{shard}"
        folder = artifact / ("en-US" if direct else "marketing/en-US")
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / name
        image = Image.new(mode, size or next(iter(SMALL_SIZES[family])), (255, 0, 0, 127) if mode == "RGBA" else (255, 0, 0))
        image.save(path)
        return path

    def package(self) -> dict:
        return package_screenshots(
            self.root, self.output, "0.5.5", COMMIT, allowed_sizes=SMALL_SIZES
        )

    def test_packages_matching_sets_and_removes_alpha(self) -> None:
        for family in ("iPhone", "iPad"):
            self.screenshot(family, "01-intro.png", mode="RGBA")
            self.screenshot(family, "02-session.png", shard=1, mode="RGB", direct=False)

        manifest = self.package()
        self.assertEqual(manifest["sourceCommit"], COMMIT)
        self.assertEqual(len(manifest["screenshots"]["iPhone"]), 2)
        with zipfile.ZipFile(self.output) as bundle:
            self.assertEqual(
                set(bundle.namelist()),
                {
                    "iPhone/en-US/01-intro.png", "iPhone/en-US/02-session.png",
                    "iPad/en-US/01-intro.png", "iPad/en-US/02-session.png", "manifest.json",
                },
            )
            self.assertEqual(json.loads(bundle.read("manifest.json")), manifest)
            for family in ("iPhone", "iPad"):
                with Image.open(io.BytesIO(bundle.read(f"{family}/en-US/01-intro.png"))) as image:
                    self.assertEqual(image.mode, "RGB")
                    self.assertEqual(image.size, next(iter(SMALL_SIZES[family])))

    def test_rejects_missing_device_or_mismatched_names(self) -> None:
        self.screenshot("iPhone")
        with self.assertRaisesRegex(PackagingError, "screenshot sets differ"):
            self.package()
        self.screenshot("iPad", "02-other.png")
        with self.assertRaisesRegex(PackagingError, "iPhone only"):
            self.package()
        self.assertFalse(self.output.exists())

    def test_rejects_duplicate_name_across_shards(self) -> None:
        self.screenshot("iPhone", shard=0)
        self.screenshot("iPhone", shard=1)
        self.screenshot("iPad")
        with self.assertRaisesRegex(PackagingError, "Duplicate iPhone screenshot"):
            self.package()

    def test_rejects_unsupported_native_size_before_creating_zip(self) -> None:
        self.screenshot("iPhone", size=(13, 27))
        self.screenshot("iPad")
        with self.assertRaisesRegex(PackagingError, "Unsupported iPhone size 13x27"):
            self.package()
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
