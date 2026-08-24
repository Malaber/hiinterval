from __future__ import annotations

import os
import shlex
from pathlib import Path

from invoke import task


ROOT = Path(__file__).resolve().parent
IOS_DIR = ROOT / "ios" / "HiIntervalIOS"
DEFAULT_IPHONE = "iPhone 17 Pro"
DEFAULT_IPAD = "iPad Pro 13-inch (M5)"


def _ios_env() -> dict[str, str]:
    module_cache = IOS_DIR / ".clang-module-cache"
    module_cache.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    env.setdefault("CLANG_MODULE_CACHE_PATH", str(module_cache))
    return env


@task
def install_xcodegen(c) -> None:
    """Install XcodeGen through Homebrew when missing."""
    c.run(
        "brew list xcodegen >/dev/null 2>&1 || brew install xcodegen",
        pty=False,
        shell="/bin/bash",
    )


@task
def generate_ios_project(c) -> None:
    """Generate ignored Xcode project from project.yml."""
    c.run(
        f"cd {shlex.quote(str(IOS_DIR))} && xcodegen generate",
        env=_ios_env(),
        pty=False,
        shell="/bin/bash",
    )


@task
def check_ios_package(c) -> None:
    """Run Swift package tests and 99% line-coverage gate."""
    c.run(
        shlex.quote(str(IOS_DIR / "Scripts" / "check_coverage.sh")),
        env=_ios_env(),
        pty=False,
        shell="/bin/bash",
    )


@task(
    help={
        "device_name": "Exact installed iOS Simulator device name.",
        "artifact_dir": "Repo-relative directory for logs and xcresult.",
        "only_testing": "XCTest target, class, or method selection.",
    }
)
def ios_ui_e2e(
    c,
    device_name=DEFAULT_IPHONE,
    artifact_dir="e2e-artifacts/ios-iphone",
    only_testing="HiIntervalUITests",
) -> None:
    """Run serial, isolated XCUITest with one full-run retry."""
    command = " ".join(
        [
            shlex.quote(str(IOS_DIR / "Scripts" / "run_ui_e2e.sh")),
            shlex.quote(device_name),
            shlex.quote(artifact_dir),
            shlex.quote(only_testing),
        ]
    )
    c.run(command, env=_ios_env(), pty=False, shell="/bin/bash")


@task(
    help={
        "device_name": "Exact installed iOS Simulator device name.",
        "configuration": "Xcode build configuration.",
    }
)
def build_ios_simulator(c, device_name=DEFAULT_IPHONE, configuration="Debug") -> None:
    """Generate and compile app for one simulator without signing."""
    install_xcodegen.body(c)
    generate_ios_project.body(c)
    command = " ".join(
        [
            f"cd {shlex.quote(str(IOS_DIR))} &&",
            "xcodebuild",
            "-project HiIntervalApp.xcodeproj",
            "-scheme HiInterval",
            f"-configuration {shlex.quote(configuration)}",
            f"-destination {shlex.quote(f'platform=iOS Simulator,name={device_name},OS=latest')}",
            "-destination-timeout 120",
            "CODE_SIGNING_ALLOWED=NO",
            "build",
        ]
    )
    c.run(command, env=_ios_env(), pty=False, shell="/bin/bash")


@task
def check_ios_ci(c) -> None:
    """Run same package, iPhone, and iPad gates used before TestFlight."""
    check_ios_package.body(c)
    install_xcodegen.body(c)
    ios_ui_e2e.body(
        c,
        device_name=DEFAULT_IPHONE,
        artifact_dir="e2e-artifacts/ios-iphone",
    )
    ios_ui_e2e.body(
        c,
        device_name=DEFAULT_IPAD,
        artifact_dir="e2e-artifacts/ios-ipad",
    )


@task(default=True)
def check(c) -> None:
    """Alias for complete native CI gate."""
    check_ios_ci.body(c)
