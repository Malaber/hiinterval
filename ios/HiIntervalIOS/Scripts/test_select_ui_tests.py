import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from select_ui_tests import shards


class ShardTests(unittest.TestCase):
    def test_repository_classes_appear_exactly_once(self):
        directory = Path(__file__).resolve().parents[1] / 'UITests'
        groups = shards(directory, 3)
        selected = [name for group in groups for name in group]
        expected = {'HiIntervalUITests/' + path.stem for path in directory.glob('*UITests.swift')}
        self.assertEqual(set(selected), expected)
        self.assertEqual(len(selected), len(expected))
        self.assertTrue(all(groups))
        self.assertEqual(groups, shards(directory, 3))

    def test_new_classes_are_included_and_balanced(self):
        with TemporaryDirectory() as directory:
            for name, count in [('A', 4), ('B', 2), ('C', 2)]:
                Path(directory, name + 'UITests.swift').write_text(
                    f'final class {name}UITests: HiIntervalUITestCase {{' +
                    ''.join(f'func test{i}() {{}}' for i in range(count)) + '}')
            self.assertEqual(shards(directory, 2), [
                ['HiIntervalUITests/AUITests'],
                ['HiIntervalUITests/BUITests', 'HiIntervalUITests/CUITests']])
            with self.assertRaises(ValueError): shards(directory, 4)
            with self.assertRaises(ValueError): shards(directory, 0)
