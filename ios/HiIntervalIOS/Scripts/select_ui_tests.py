#!/usr/bin/env python3
"""Deterministic, disjoint UI class shards balanced by test-method count."""
import argparse
from pathlib import Path
import re


def shards(directory, count):
    if count < 1:
        raise ValueError('shard count must be positive')
    classes = []
    for path in sorted(Path(directory).glob('*UITests.swift')):
        source = path.read_text()
        names = re.findall(r'final class (\w+UITests): HiIntervalUITestCase', source)
        methods = re.findall(r'func (test\w+)\(', source)
        if len(names) != 1 or not methods:
            raise ValueError(f'Cannot discover test class/methods in {path}')
        classes.append((len(methods), names[0]))
    if len(classes) < count:
        raise ValueError('shard count would produce empty shards')
    groups, loads = [[] for _ in range(count)], [0] * count
    for size, name in sorted(classes, key=lambda item: (-item[0], item[1])):
        index = min(range(count), key=lambda index: (loads[index], index))
        groups[index].append('HiIntervalUITests/' + name)
        loads[index] += size
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
