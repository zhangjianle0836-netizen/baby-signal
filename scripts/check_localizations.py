#!/usr/bin/env python3
"""Check shared translation coverage and format arguments using the standard library."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAIR = re.compile(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;')
PLACEHOLDER = re.compile(r'%(?:\d+\$)?[@dfius]')


def read_table(path: Path) -> dict[str, str]:
    """Read this project's JSON-compatible .strings entries and reject duplicate keys."""
    pairs = [(json.loads(key), json.loads(value)) for key, value in PAIR.findall(path.read_text())]
    result = dict(pairs)
    assert len(result) == len(pairs), f"Duplicate keys: {path}"
    return result


def main() -> None:
    """Validate both shared tables and every Chinese Swift string key."""
    root = ROOT / 'Shared/Localization'
    english = read_table(root / 'en.lproj/Localizable.strings')
    chinese = read_table(root / 'zh-Hans.lproj/Localizable.strings')
    assert english.keys() == chinese.keys(), 'Translation keys differ'
    for key in english:
        assert english[key].strip(), f'Empty English translation: {key}'
        assert PLACEHOLDER.findall(english[key]) == PLACEHOLDER.findall(chinese[key]), key
    for directory in ['BabySignal', 'BabySignalLiveActivity']:
        for path in (ROOT / directory).rglob('*.swift'):
            for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', path.read_text()):
                if re.search(r'[\u4e00-\u9fff]', match[1]):
                    key = json.loads(match[0])
                    assert key in english, f'Missing translation in {path}: {key}'
        en_info = read_table(ROOT / directory / 'en.lproj/InfoPlist.strings')
        zh_info = read_table(ROOT / directory / 'zh-Hans.lproj/InfoPlist.strings')
        assert en_info.keys() == zh_info.keys(), f'InfoPlist coverage differs: {directory}'
    print(f'PASS: {len(english)} shared bilingual keys, matching placeholders and permission/name resources')


if __name__ == '__main__':
    main()
