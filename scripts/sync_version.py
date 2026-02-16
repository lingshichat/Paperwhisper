#!/usr/bin/env python3
"""
版本号同步脚本
从 releases/version.json 同步版本号到各个位置

用法:
    python scripts/sync_version.py
"""

import json
import re
import sys
from pathlib import Path


def get_project_root() -> Path:
    """获取项目根目录"""
    script_path = Path(__file__).resolve()
    return script_path.parent.parent


def read_source_version() -> dict:
    """读取源版本文件"""
    root = get_project_root()
    version_file = root / "releases" / "version.json"

    if not version_file.exists():
        print(f"[ERROR] 找不到源版本文件 {version_file}")
        sys.exit(1)

    with open(version_file, "r", encoding="utf-8") as f:
        return json.load(f)


def sync_flutter_assets(version_data: dict) -> bool:
    """同步到 Flutter assets/version.json"""
    root = get_project_root()
    target_file = root / "paper_whisper_flutter" / "assets" / "version.json"

    if not target_file.exists():
        print(f"[WARN] 找不到目标文件 {target_file}")
        return False

    # 写入新内容（保留 JSON 格式）
    with open(target_file, "w", encoding="utf-8") as f:
        json.dump(version_data, f, ensure_ascii=False, indent=4)
        f.write("\n")

    print(f"[OK] 已同步到 {target_file}")
    print(f"     版本: {version_data['latestVersion']}+{version_data['latestBuildNumber']}")
    return True


def sync_pubspec(version_data: dict) -> bool:
    """同步到 pubspec.yaml"""
    root = get_project_root()
    pubspec_file = root / "paper_whisper_flutter" / "pubspec.yaml"

    if not pubspec_file.exists():
        print(f"[WARN] 找不到 pubspec.yaml {pubspec_file}")
        return False

    version = version_data["latestVersion"]
    build_number = version_data["latestBuildNumber"]
    new_version_line = f"version: {version}+{build_number}"

    with open(pubspec_file, "r", encoding="utf-8") as f:
        content = f.read()

    # 替换版本号行
    pattern = r"^version:\s*\S+\s*\+\s*\d+$"
    replacement = new_version_line

    new_content, count = re.subn(pattern, replacement, content, flags=re.MULTILINE)

    if count == 0:
        # 尝试另一种格式 (没有空格)
        pattern = r"^version:\s*[^\s#]+"
        new_content, count = re.subn(pattern, new_version_line, content, flags=re.MULTILINE)

    if count == 0:
        print(f"[WARN] 在 pubspec.yaml 中未找到版本号行")
        return False

    with open(pubspec_file, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"[OK] 已同步到 {pubspec_file}")
    print(f"     版本: {version}+{build_number}")
    return True


def main():
    print("=" * 50)
    print("开始同步版本号")
    print("=" * 50)

    # 读取源版本
    version_data = read_source_version()
    version = version_data["latestVersion"]
    build_number = version_data["latestBuildNumber"]

    print(f"\n[源版本信息]")
    print(f"   版本号: {version}")
    print(f"   构建号: {build_number}")
    print(f"   发布日期: {version_data.get('releaseDate', 'N/A')}")
    print(f"   标题: {version_data.get('title', 'N/A')}")
    print()

    # 同步到各个位置
    results = []
    results.append(("Flutter assets/version.json", sync_flutter_assets(version_data)))
    results.append(("pubspec.yaml", sync_pubspec(version_data)))

    print()
    print("=" * 50)
    print("同步结果")
    print("=" * 50)

    success_count = sum(1 for _, result in results if result)
    for name, result in results:
        status = "[OK] 成功" if result else "[FAIL] 失败"
        print(f"   {status}: {name}")

    print()
    if success_count == len(results):
        print("所有文件同步成功!")
        return 0
    else:
        print(f"部分同步失败 ({success_count}/{len(results)})")
        return 1


if __name__ == "__main__":
    sys.exit(main())
