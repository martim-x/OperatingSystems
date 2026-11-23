import pathlib
import re
import subprocess
import sys
import unittest

BIN = pathlib.Path(sys.argv.pop(1)).resolve()
SUFFIX = '.exe' if sys.platform == 'win32' else ''


def run(name, *args):
    return subprocess.run([str(BIN / (name + SUFFIX)), *map(str, args)], capture_output=True, text=True, timeout=22)


class Tests(unittest.TestCase):
    def test_matrix_parallel_matches_reference_and_single_worker(self):
        results = []
        for n in (1, 3, 10):
            p = run('Lab-06-bar', n, 7, 3)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn('serial check: OK', p.stdout)
            rows = [s for s in p.stdout.splitlines() if re.fullmatch(r'-?\d+ -?\d+ -?\d+', s)]
            self.assertEqual(len(rows), 3)
            results.append(rows)
        self.assertEqual(results[0], results[1])
        self.assertEqual(results[1], results[2])
        self.assertNotEqual(run('Lab-06-bar', 1, 0, 3).returncode, 0)

    def test_buffer_full_and_empty(self):
        for a, b, blocked in ((0, 90, 'producer waits (full)'), (90, 0, 'consumer waits (empty)')):
            with self.subTest(blocked=blocked):
                p = run('Lab-06-conds', 1, a, a+2, b, b+2, '--seconds', 6)
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertIn(blocked, p.stdout)
                self.assertIn('stats elapsed=', p.stdout)
                self.assertIn('wakes', p.stdout)
                self.assertIn('user=User-6d4ec851 buffer=0 capacity=1', p.stdout)
                added = re.findall(r'added=(\d+) buffer=1', p.stdout)
                taken = re.findall(r'removed=(\d+) buffer=0', p.stdout)
                self.assertTrue(added)
                self.assertEqual(added, [str(i) for i in range(1, len(added)+1)])
                self.assertEqual(added, taken)
                self.assertIn(f'final produced={len(added)} consumed={len(taken)} buffer=0', p.stdout)
                snapshot = re.search(r'stats elapsed=([\d.]+)s produced=(\d+) consumed=(\d+) buffer=(\d+)', p.stdout)
                if snapshot is None:
                    self.fail('missing periodic statistics')
                elapsed, produced, consumed, occupied = snapshot.groups()
                self.assertGreaterEqual(float(elapsed), 5.0)
                self.assertEqual(int(produced) - int(consumed), int(occupied))


if __name__ == '__main__':
    unittest.main()
