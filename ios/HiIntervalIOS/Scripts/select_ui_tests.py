#!/usr/bin/env python3
"""Select deterministic, disjoint UI test-method shards."""
import argparse
from pathlib import Path
import re


CLASS_PATTERN = re.compile(
    r'^\s*(?:final\s+)?class\s+(\w+UITests)\s*:\s*HiIntervalUITestCase\s*\{',
    re.MULTILINE,
)
METHOD_PATTERN = re.compile(r'^\s*func\s+(test\w+)\s*\(', re.MULTILINE)


def shards(directory, count):
    if count < 1:
        raise ValueError('shard count must be positive')

    discovered = {}
    for path in sorted(Path(directory).glob('*UITests.swift')):
        source = path.read_text()
        classes = CLASS_PATTERN.findall(source)
        methods = METHOD_PATTERN.findall(source)
        if len(classes) != 1 or not methods:
            raise ValueError(f'Cannot discover one test class with methods in {path}')
        name = classes[0]
        if name in discovered:
            raise ValueError(f'Duplicate UI test class: {name}')
        if len(methods) != len(set(methods)):
            raise ValueError(f'Duplicate UI test method in {path}')
        discovered[name] = methods

    selectors = [
        f'HiIntervalUITests/{name}/{method}'
        for name in sorted(discovered)
        for method in sorted(discovered[name])
    ]
    if len(selectors) < count:
        raise ValueError('shard count would produce empty shards')

    groups = [[] for _ in range(count)]
    for index, selector in enumerate(selectors):
        groups[index % count].append(selector)
    return groups


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory')
    parser.add_argument('index', type=int)
    parser.add_argument('count', type=int)
    args = parser.parse_args()
    try:
        if not 0 <= args.index < args.count:
            raise ValueError('shard index must be within count')
        print('\n'.join(shards(args.directory, args.count)[args.index]))
    except ValueError as error:
        parser.error(str(error))
