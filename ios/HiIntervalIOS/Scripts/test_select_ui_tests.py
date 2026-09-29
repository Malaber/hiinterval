import re
import subprocess
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from select_ui_tests import shards


SCRIPT = Path(__file__).with_name('select_ui_tests.py')


def write_test_class(directory, name, methods):
    Path(directory, name + 'UITests.swift').write_text(
        f'final class {name}UITests: HiIntervalUITestCase {{\n'
        + ''.join(f'    func {method}() {{}}\n' for method in methods)
        + '}\n'
    )


class ShardTests(unittest.TestCase):
    def test_repository_methods_appear_exactly_once(self):
        directory = Path(__file__).resolve().parents[1] / 'UITests'
        groups = shards(directory, 3)
        selected = [selector for group in groups for selector in group]
        expected = {
            f'HiIntervalUITests/{path.stem}/{method}'
            for path in directory.glob('*UITests.swift')
            for method in re.findall(r'^\s*func\s+(test\w+)\s*\(', path.read_text(), re.MULTILINE)
        }
        self.assertEqual(set(selected), expected)
        self.assertEqual(len(selected), len(expected))
        self.assertTrue(all(groups))
        self.assertLessEqual(max(map(len, groups)) - min(map(len, groups)), 1)
        self.assertEqual(groups, shards(directory, 3))

    def test_new_methods_and_classes_balance_even_with_one_large_class(self):
        with TemporaryDirectory() as directory:
            write_test_class(directory, 'A', [f'test{i}' for i in range(11)])
            write_test_class(directory, 'B', ['testAdded'])
            write_test_class(directory, 'C', ['testOther'])
            groups = shards(directory, 3)
            self.assertEqual(list(map(len, groups)), [5, 4, 4])
            self.assertEqual(
                {selector for group in groups for selector in group},
                {f'HiIntervalUITests/AUITests/test{i}' for i in range(11)}
                | {'HiIntervalUITests/BUITests/testAdded', 'HiIntervalUITests/CUITests/testOther'},
            )
            self.assertTrue(all(any('/AUITests/' in selector for selector in group) for group in groups))

            write_test_class(directory, 'B', ['testAdded', 'testNew'])
            self.assertIn('HiIntervalUITests/BUITests/testNew', sum(shards(directory, 3), []))

    def test_invalid_discovery_and_empty_shards_fail(self):
        with TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'empty shards'):
                shards(directory, 1)
            with self.assertRaisesRegex(ValueError, 'positive'):
                shards(directory, 0)

            write_test_class(directory, 'A', ['testOne'])
            with self.assertRaisesRegex(ValueError, 'empty shards'):
                shards(directory, 2)

            Path(directory, 'BrokenUITests.swift').write_text('final class BrokenUITests: HiIntervalUITestCase {}')
            with self.assertRaisesRegex(ValueError, 'Cannot discover'):
                shards(directory, 1)
            Path(directory, 'BrokenUITests.swift').unlink()

            write_test_class(directory, 'B', ['testOne', 'testOne'])
            with self.assertRaisesRegex(ValueError, 'Duplicate UI test method'):
                shards(directory, 1)
            Path(directory, 'BUITests.swift').unlink()

            write_test_class(directory, 'B', ['testTwo'])
            Path(directory, 'BUITests.swift').write_text(
                'final class AUITests: HiIntervalUITestCase {\n    func testTwo() {}\n}'
            )
            with self.assertRaisesRegex(ValueError, 'Duplicate UI test class'):
                shards(directory, 1)

    def test_cli_rejects_invalid_index(self):
        with TemporaryDirectory() as directory:
            write_test_class(directory, 'A', ['testOne', 'testTwo'])
            for index in ('-1', '2'):
                result = subprocess.run(
                    [sys.executable, SCRIPT, directory, index, '2'],
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('shard index must be within count', result.stderr)


if __name__ == '__main__':
    unittest.main()
