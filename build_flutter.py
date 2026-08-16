#!/usr/bin/env python3
"""
构建墨阅 Flutter 应用。

用法
====

在本文件所在的 Flutter 项目根目录中执行：

    python build_flutter.py TARGET [--mode MODE]
                            [--split-per-abi | --android-abi ABI]

也可以查看 argparse 生成的简短帮助：

    python build_flutter.py --help

TARGET 是必填的构建目标，可选值如下：

    web       构建 Web 应用
    linux     构建 Linux 桌面应用
    windows   构建 Windows 桌面应用
    apk       构建 Android APK，不需上传 Google Play
    ios       构建 iOS 应用

MODE 是可选的构建模式，通过 --mode 传入：

    release   发布版（默认）
    debug     调试版
    profile   性能分析版

Android APK 可选参数
====================

    --split-per-abi
        一次构建 armeabi-v7a、arm64-v8a 和 x86_64 三份较小的 APK。

    --android-abi ABI
        只构建指定架构的一份 APK。ABI 可选值为
        armeabi-v7a、arm64-v8a 或 x86_64。

这两个参数互斥，且只能和 apk 目标一起使用。两者都不传时，
构建同时包含三种架构的通用 APK。

常用示例
========

    python build_flutter.py apk
    python build_flutter.py apk --mode debug
    python build_flutter.py apk --split-per-abi
    python build_flutter.py apk --android-abi arm64-v8a
    python build_flutter.py web
    python build_flutter.py linux --mode release
    python build_flutter.py windows --mode release
    python build_flutter.py ios --mode release

操作系统限制
============

    web       Windows、Linux 和 macOS 都可构建
    apk       Windows、Linux 和 macOS 都可构建
    windows   只能在 Windows 上构建
    linux     只能在 Linux 上构建
    ios       只能在 macOS 上构建，并需要 Xcode

构建前提
========

* Flutter SDK 需要在 PATH 中。
* Android APK 需要 Android SDK 以及 JDK 17 或更高版本。
* 在 Windows 上构建 APK 时，脚本会优先使用项目上级目录中的
  ``jdk-17.0.20+8``，然后尝试 JAVA_HOME 和 PATH 中的 Java。
* Linux、Windows 和 iOS 桌面构建还需要 Flutter 对应平台的本机工具链。

预期产物
========

    apk       build/app/outputs/flutter-apk/app-<mode>.apk
    拆分 APK  build/app/outputs/flutter-apk/app-<abi>-<mode>.apk
    web       build/web/
    linux     build/linux/<arch>/<mode>/bundle/
    windows   build/windows/.../runner/<mode>/
    ios       build/ios/iphoneos/Runner.app

脚本会自动识别 Windows、Linux 或 macOS，检查目标是否可在当前系统
构建，通过标准 ``flutter build`` 命令执行对应构建，并在成功后
打印所有产物的绝对路径和文件大小。

退出码：0 表示构建成功；1 表示命令执行或产物检查失败；2 表示本机配置
或平台不支持；130 表示用户中断构建。
"""

from __future__ import annotations

import argparse
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Iterable, Optional


PROJECT_DIR = Path(__file__).resolve().parent
BUILD_TARGETS = ("web", "linux", "windows", "apk", "ios")
BUILD_MODES = ("release", "debug", "profile")
ANDROID_ABIS = {
    "armeabi-v7a": "android-arm",
    "arm64-v8a": "android-arm64",
    "x86_64": "android-x64",
}
HOST_REQUIREMENTS = {
    "linux": "Linux",
    "windows": "Windows",
    "ios": "Darwin",
}


class BuildError(RuntimeError):
    """A configuration or build error that can be shown directly to the user."""


def java_binary(java_home: Path, system_name: str) -> Path:
    executable = "java.exe" if system_name == "Windows" else "java"
    return java_home / "bin" / executable


def java_major_version(java_home: Path, system_name: str) -> Optional[int]:
    java = java_binary(java_home, system_name)
    if not java.is_file():
        return None

    try:
        result = subprocess.run(
            [str(java), "-version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    version_text = f"{result.stdout}\n{result.stderr}"
    match = re.search(r'version\s+"?(\d+)(?:\.(\d+))?', version_text)
    if not match:
        return None

    major = int(match.group(1))
    if major == 1 and match.group(2):
        major = int(match.group(2))
    return major


def unique_existing_paths(paths: Iterable[Optional[Path]]) -> list[Path]:
    result: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        if path is None:
            continue
        expanded = path.expanduser()
        key = os.path.normcase(str(expanded))
        if key not in seen:
            seen.add(key)
            result.append(expanded)
    return result


def java_home_from_path() -> Optional[Path]:
    java = shutil.which("java")
    if not java:
        return None
    try:
        return Path(java).resolve().parent.parent
    except OSError:
        return None


def macos_java_17_home() -> Optional[Path]:
    helper = Path("/usr/libexec/java_home")
    if not helper.is_file():
        return None
    try:
        result = subprocess.run(
            [str(helper), "-v", "17"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return Path(result.stdout.strip())


def find_java_home(system_name: str) -> tuple[Path, int]:
    configured_home = os.environ.get("JAVA_HOME")
    candidates: list[Optional[Path]] = []

    if system_name == "Windows":
        # This repository includes the JDK used by the Android build on Windows.
        candidates.extend(
            [
                PROJECT_DIR.parent / "jdk-17.0.20+8",
                Path(configured_home) if configured_home else None,
                java_home_from_path(),
            ]
        )
    elif system_name == "Darwin":
        candidates.extend(
            [
                macos_java_17_home(),
                Path(configured_home) if configured_home else None,
                Path("/Applications/Android Studio.app/Contents/jbr/Contents/Home"),
                java_home_from_path(),
            ]
        )
    elif system_name == "Linux":
        candidates.extend(
            [
                Path(configured_home) if configured_home else None,
                Path("/usr/lib/jvm/java-17-openjdk-amd64"),
                Path("/usr/lib/jvm/java-17-openjdk"),
                Path("/opt/android-studio/jbr"),
                java_home_from_path(),
            ]
        )
    else:
        raise BuildError(f"不支持的操作系统：{system_name}")

    supported: list[tuple[Path, int]] = []
    for candidate in unique_existing_paths(candidates):
        major = java_major_version(candidate, system_name)
        if major is not None and major >= 17:
            supported.append((candidate, major))

    if not supported:
        raise BuildError(
            "没有找到 JDK 17 或更高版本。请安装 JDK 17，或正确设置 JAVA_HOME。"
        )

    # Prefer JDK 17 when available; otherwise use the first compatible JDK.
    return next((item for item in supported if item[1] == 17), supported[0])


def windows_batch_command(batch_file: Path, arguments: list[str]) -> list[str]:
    command_processor = os.environ.get("COMSPEC", "cmd.exe")
    return [command_processor, "/d", "/c", "call", str(batch_file), *arguments]


def flutter_build_command(
    system_name: str,
    target: str,
    mode: str,
    extra_arguments: Optional[list[str]] = None,
) -> list[str]:
    required_host = HOST_REQUIREMENTS.get(target)
    if required_host is not None and system_name != required_host:
        display_host = "macOS" if required_host == "Darwin" else required_host
        raise BuildError(f"{target} 版本只能在 {display_host} 上构建。")

    flutter_name = "flutter.bat" if system_name == "Windows" else "flutter"
    flutter = shutil.which(flutter_name) or shutil.which("flutter")
    if not flutter:
        raise BuildError("没有在 PATH 中找到 Flutter SDK。")

    arguments = ["build", target, f"--{mode}", *(extra_arguments or [])]
    flutter_path = Path(flutter)
    if system_name == "Windows" and flutter_path.suffix.lower() in {".bat", ".cmd"}:
        return windows_batch_command(flutter_path, arguments)
    return [str(flutter_path), *arguments]


def build_command(
    system_name: str,
    target: str,
    mode: str,
    split_per_abi: bool,
    android_abi: Optional[str],
) -> tuple[list[str], dict[str, str], Optional[tuple[Path, int]]]:
    environment = os.environ.copy()
    if target != "apk":
        return flutter_build_command(system_name, target, mode), environment, None

    java_home, java_major = find_java_home(system_name)
    environment["JAVA_HOME"] = str(java_home)
    java_bin_dir = java_binary(java_home, system_name).parent
    environment["PATH"] = str(java_bin_dir) + os.pathsep + environment.get("PATH", "")
    apk_arguments: list[str] = []
    if split_per_abi:
        apk_arguments.append("--split-per-abi")
    elif android_abi:
        apk_arguments.append(f"--target-platform={ANDROID_ABIS[android_abi]}")
    return (
        flutter_build_command(system_name, target, mode, apk_arguments),
        environment,
        (java_home, java_major),
    )


def display_command(command: list[str], system_name: str) -> str:
    if system_name == "Windows":
        return subprocess.list2cmdline(command)
    return shlex.join(command)


def find_artifacts(target: str, mode: str, split_per_abi: bool) -> list[Path]:
    build_dir = PROJECT_DIR / "build"
    mode_title = mode.capitalize()

    if target == "apk":
        flutter_apk_dir = build_dir / "app" / "outputs" / "flutter-apk"
        if split_per_abi:
            artifacts = [
                flutter_apk_dir / f"app-{abi}-{mode}.apk" for abi in ANDROID_ABIS
            ]
            return artifacts if all(path.is_file() for path in artifacts) else []

        apk_name = f"app-{mode}.apk"
        candidates = (
            flutter_apk_dir / apk_name,
            build_dir / "app" / "outputs" / "apk" / mode / apk_name,
        )
        artifact = next((path for path in candidates if path.is_file()), None)
        return [artifact] if artifact else []

    if target == "web":
        web_dir = build_dir / "web"
        return [web_dir] if (web_dir / "index.html").is_file() else []

    if target == "ios":
        ios_app = build_dir / "ios" / "iphoneos" / "Runner.app"
        return [ios_app] if ios_app.is_dir() else []

    if target == "windows":
        windows_dir = build_dir / "windows"
        expected_name = f"{PROJECT_DIR.name}.exe"
        executables = list(windows_dir.rglob(expected_name)) if windows_dir.is_dir() else []
        if executables:
            return [executables[0]]
        fallback = windows_dir / "x64" / "runner" / mode_title
        return [fallback] if fallback.is_dir() else []

    linux_dir = build_dir / "linux"
    bundles = list(linux_dir.glob(f"*/{mode}/bundle")) if linux_dir.is_dir() else []
    return [bundles[0]] if bundles else []


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="构建墨月 Flutter 应用。",
        epilog=(
            "示例：python build_flutter.py apk；"
            "python build_flutter.py apk --split-per-abi；"
            "python build_flutter.py apk --android-abi arm64-v8a；"
            "python build_flutter.py web；"
            "python build_flutter.py apk --mode debug"
        ),
    )
    parser.add_argument(
        "target",
        choices=BUILD_TARGETS,
        help="目标平台：web、linux、windows、apk 或 ios",
    )
    parser.add_argument(
        "--mode",
        choices=BUILD_MODES,
        default="release",
        help="构建模式，默认为 release",
    )
    apk_group = parser.add_mutually_exclusive_group()
    apk_group.add_argument(
        "--split-per-abi",
        action="store_true",
        help="APK 按 CPU 架构拆分为三份较小的文件",
    )
    apk_group.add_argument(
        "--android-abi",
        choices=tuple(ANDROID_ABIS),
        help="只构建指定 CPU 架构的 APK",
    )
    arguments = parser.parse_args()
    if arguments.target != "apk" and (
        arguments.split_per_abi or arguments.android_abi
    ):
        parser.error("--split-per-abi 和 --android-abi 只能和 apk 目标一起使用")
    return arguments


def configure_output_encoding() -> None:
    # Keep Chinese status messages readable when output is captured or redirected.
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is not None:
            reconfigure(encoding="utf-8", errors="replace")


def main() -> int:
    configure_output_encoding()
    arguments = parse_arguments()
    system_name = platform.system()
    display_name = "macOS" if system_name == "Darwin" else system_name

    try:
        command, environment, java_info = build_command(
            system_name,
            arguments.target,
            arguments.mode,
            arguments.split_per_abi,
            arguments.android_abi,
        )
    except BuildError as error:
        print(f"\n构建配置错误：{error}", file=sys.stderr)
        return 2

    print(f"操作系统：{display_name}")
    print(f"目标平台：{arguments.target}")
    print(f"构建模式：{arguments.mode}")
    if arguments.target == "apk":
        if arguments.split_per_abi:
            print("APK 架构：按 ABI 拆分")
        elif arguments.android_abi:
            print(f"APK 架构：{arguments.android_abi}")
        else:
            print("APK 架构：通用 APK")
    if java_info is not None:
        java_home, java_major = java_info
        print(f"使用 JDK：{java_home}（Java {java_major}）")
    print(f"构建命令：{display_command(command, system_name)}")
    print(f"\n开始构建 {arguments.target} {arguments.mode} 版本...\n", flush=True)

    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_DIR,
            env=environment,
            check=False,
        )
    except KeyboardInterrupt:
        print("\n构建已取消。", file=sys.stderr)
        return 130
    except OSError as error:
        print(f"\n无法启动构建命令：{error}", file=sys.stderr)
        return 1

    if result.returncode != 0:
        print(f"\n构建失败，退出码：{result.returncode}", file=sys.stderr)
        return result.returncode

    artifacts = find_artifacts(
        arguments.target,
        arguments.mode,
        arguments.split_per_abi,
    )
    if not artifacts:
        print("\n构建命令成功，但没有在预期位置找到产物。", file=sys.stderr)
        return 1

    print("\n构建成功！")
    for artifact in artifacts:
        if artifact.is_file():
            size_mb = artifact.stat().st_size / (1024 * 1024)
            print(f"产物：{artifact}（{size_mb:.2f} MB）")
        else:
            print(f"产物：{artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
