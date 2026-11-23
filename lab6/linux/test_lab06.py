#!/usr/bin/env python3
"""Black-box acceptance tests for Linux Lab 6 level 4-5."""
from __future__ import annotations

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
USER_NAME = "User-6d4ec851"
ITERATIONS = 100


class Lab06Acceptance(unittest.TestCase):
    def run_program(self, source: str) -> str:
        with tempfile.TemporaryDirectory(prefix="lab06-") as temp:
            binary = Path(temp) / source.removesuffix(".c")
            compile_result = subprocess.run(
                ["gcc", "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror", "-pthread",
                 str(HERE / source), "-o", str(binary)],
                check=False,
                cwd=HERE,
                text=True,
                capture_output=True,
            )
            self.assertEqual(compile_result.returncode, 0,
                             f"{source} must compile cleanly:\\n{compile_result.stderr}")
            completed = subprocess.run(
                [str(binary)],
                check=True,
                cwd=HERE,
                text=True,
                capture_output=True,
                timeout=45,
            )
            self.assertEqual(completed.stderr, "", "program wrote diagnostics to stderr")
            return completed.stdout

    def assert_output_contract(self, output: str, *, process_workers: bool) -> None:
        iteration_re = re.compile(
            r"^ITER worker=(main|A|B) pid=(\d+) i=(\d+) user=(.)$", re.MULTILINE
        )
        iterations = [(w, int(pid), int(i), user) for w, pid, i, user in iteration_re.findall(output)]
        self.assertEqual(len(iterations), 3 * ITERATIONS, "expected 100 iteration records per worker")

        by_worker: dict[str, list[tuple[int, int, str]]] = {"main": [], "A": [], "B": []}
        for worker, pid, iteration, symbol in iterations:
            by_worker[worker].append((pid, iteration, symbol))
        worker_pids: dict[str, int] = {}
        for worker, records in by_worker.items():
            with self.subTest(worker=worker):
                self.assertEqual(len(records), ITERATIONS)
                self.assertEqual([i for _, i, _ in records], list(range(1, ITERATIONS + 1)))
                worker_pid_set = {pid for pid, _, _ in records}
                self.assertEqual(len(worker_pid_set), 1, "one worker must keep one process identity")
                worker_pids[worker] = next(iter(worker_pid_set))
                self.assertEqual(
                    [symbol for _, _, symbol in records],
                    [USER_NAME[(i - 1) % len(USER_NAME)] for i in range(1, ITERATIONS + 1)],
                )
        pids = {pid for records in by_worker.values() for pid, _, _ in records}
        self.assertEqual(len(pids), 3 if process_workers else 1,
                         "fork version must have three processes; pthread version one process")

        event_re = re.compile(r"^(ENTER|LEAVE) worker=(main|A|B) pid=(\d+) i=(\d+)$", re.MULTILINE)
        events = [(kind, worker, int(pid), int(i)) for kind, worker, pid, i in event_re.findall(output)]
        self.assertEqual(len(events), 6, "each worker must announce entry and exit of [30, 60]")
        active: tuple[str, int] | None = None
        for kind, worker, pid, iteration in events:
            if kind == "ENTER":
                self.assertIsNone(active, f"protected intervals overlap; {worker} entered while {active} active")
                self.assertEqual(iteration, 30)
                active = (worker, pid)
            else:
                self.assertEqual(active, (worker, pid), "exit does not match the current owner")
                self.assertEqual(iteration, 60)
                active = None
        self.assertIsNone(active, "protected interval was not released")

        owner: tuple[str, int] | None = None
        current_interval_count = 0
        for line in output.splitlines():
            event_match = event_re.fullmatch(line)
            if event_match:
                kind, worker, pid, _iteration = event_match.groups()
                if kind == "ENTER":
                    owner = (worker, int(pid))
                    current_interval_count = 0
                else:
                    self.assertEqual(current_interval_count, 31,
                                     "protected interval must cover every inclusive iteration 30..60")
                    owner = None
                continue
            match = iteration_re.fullmatch(line)
            if match:
                worker, pid, iteration, _symbol = match.groups()
                iteration = int(iteration)
                inside = 30 <= iteration <= 60
                if inside:
                    self.assertEqual(owner, (worker, int(pid)),
                                     f"iteration {worker}:{iteration} ran outside its exclusive interval")
                    current_interval_count += 1
        self.assertIsNone(owner)
        self.assertEqual(set(worker_pids), {"main", "A", "B"})
        print(
            f"REAL RUN {'Lab-06b' if process_workers else 'Lab-06a'}: "
            f"{len(iterations)} iterations ({', '.join(f'{name}=100' for name in ('main', 'A', 'B'))}); "
            f"PIDs={worker_pids}; exclusive owners={','.join(worker for kind, worker, _, _ in events if kind == 'ENTER')}"
        )

    def test_06a_pthreads_exclude_30_through_60(self) -> None:
        self.assert_output_contract(self.run_program("Lab-06a.c"), process_workers=False)

    def test_06b_forked_processes_share_binary_semaphore(self) -> None:
        self.assert_output_contract(self.run_program("Lab-06b.c"), process_workers=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
