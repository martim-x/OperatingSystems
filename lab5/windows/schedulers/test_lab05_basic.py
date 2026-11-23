"""Tests for the Lab 05 scheduling simulators."""

import subprocess
import sys
import unittest
from pathlib import Path

import lab05_basic as scheduler


ROOT = Path(__file__).resolve().parent


def job(pid, arrival, burst, priority=0):
    return scheduler.Job(pid, arrival, burst, priority)


class SchedulerTests(unittest.TestCase):
    @staticmethod
    def spans(result):
        return [(part.pid, part.start, part.end) for part in result.timeline]

    def test_sjf_nonpreemptive_shortest_first_and_idle_gap(self):
        result = scheduler.simulate_sjf(
            [job(1, 0, 4), job(2, 0, 2), job(3, 8, 1)]
        )
        self.assertEqual(
            self.spans(result),
            [(2, 0, 2), (1, 2, 6), (None, 6, 8), (3, 8, 9)],
        )
        rows = {row.pid: row for row in result.rows}
        self.assertEqual((rows[1].start, rows[1].finish, rows[1].waiting), (2, 6, 2))
        self.assertEqual((rows[2].start, rows[2].finish, rows[2].waiting), (0, 2, 0))
        self.assertEqual((rows[3].start, rows[3].finish, rows[3].waiting), (8, 9, 0))

    def test_sjf_ties_use_arrival_then_input_order(self):
        result = scheduler.simulate_sjf(
            [job(7, 0, 2), job(8, 0, 2), job(9, 1, 1)]
        )
        self.assertEqual(self.spans(result), [(7, 0, 2), (9, 2, 3), (8, 3, 5)])

    def test_single_late_job_metrics_and_idle_timeline(self):
        result = scheduler.simulate_sjf([job(1, 5, 3)])
        self.assertEqual(self.spans(result), [(None, 0, 5), (1, 5, 8)])
        self.assertEqual(result.rows[0].turnaround, 3)
        self.assertAlmostEqual(result.metrics.average_waiting, 0)
        self.assertAlmostEqual(result.metrics.average_service, 3)
        self.assertAlmostEqual(result.metrics.average_turnaround, 3)
        self.assertAlmostEqual(result.metrics.throughput, 1 / 8)

    def test_rr_enqueues_boundary_arrivals_before_expired_task(self):
        result = scheduler.simulate_rr([job(1, 0, 4), job(2, 2, 1)], quantum=2)
        self.assertEqual(self.spans(result), [(1, 0, 2), (2, 2, 3), (1, 3, 5)])

    def test_rr_arrivals_during_a_slice_join_ready_queue_in_order(self):
        result = scheduler.simulate_rr([job(1, 0, 5), job(2, 1, 1)], quantum=3)
        self.assertEqual(self.spans(result), [(1, 0, 3), (2, 3, 4), (1, 4, 6)])

    def test_cp_higher_numeric_priority_preempts_on_arrival(self):
        result = scheduler.simulate_cp(
            [job(1, 0, 5, 3), job(2, 2, 1, 5)], quantum=10
        )
        self.assertEqual(self.spans(result), [(1, 0, 2), (2, 2, 3), (1, 3, 6)])

    def test_cp_equal_priority_arrival_does_not_preempt(self):
        result = scheduler.simulate_cp(
            [job(1, 0, 5, 3), job(2, 1, 1, 3)], quantum=10
        )
        self.assertEqual(self.spans(result), [(1, 0, 5), (2, 5, 6)])

    def test_cp_rotates_equal_priority_tasks_at_quantum_boundary(self):
        result = scheduler.simulate_cp(
            [job(1, 0, 5, 3), job(2, 1, 3, 3)], quantum=2
        )
        self.assertEqual(
            self.spans(result),
            [(1, 0, 2), (2, 2, 4), (1, 4, 6), (2, 6, 7), (1, 7, 8)],
        )

    def test_invalid_inputs_are_rejected(self):
        with self.assertRaises(ValueError):
            scheduler.simulate_rr([job(1, 0, 1)], quantum=0)
        with self.assertRaises(ValueError):
            scheduler.simulate_sjf([job(1, -1, 1)])
        with self.assertRaises(ValueError):
            scheduler.simulate_cp([job(1, 0, 0)], quantum=1)

    def test_fixed_input_matches_backlog_dataset(self):
        self.assertEqual(len(scheduler.DEFAULT_JOBS), 10)
        self.assertEqual(
            [(item.pid, item.arrival, item.burst, item.priority) for item in scheduler.DEFAULT_JOBS],
            [
                (1, 0, 80, 3),
                (2, 20, 45, 5),
                (3, 30, 60, 2),
                (4, 50, 30, 4),
                (5, 70, 90, 1),
                (6, 100, 55, 3),
                (7, 120, 75, 2),
                (8, 150, 40, 5),
                (9, 180, 65, 4),
                (10, 200, 85, 1),
            ],
        )

    def test_cp_quantum_choice_minimizes_waiting_for_fixed_dataset(self):
        results = [scheduler.simulate_cp(quantum=q)
                   for q in scheduler.QUANTUM_CANDIDATES]
        chosen = scheduler.select_quantum(results)
        self.assertEqual(chosen.quantum, 30)
        self.assertAlmostEqual(chosen.metrics.average_waiting, 174.0)

    def test_report_contains_input_results_timeline_metrics_and_quantum_choice(self):
        report = scheduler.format_report("rr")
        self.assertIn("INPUT", report)
        self.assertIn("RESULTS", report)
        self.assertIn("TIMELINE", report)
        self.assertIn("average waiting", report.lower())
        self.assertIn("average service", report.lower())
        self.assertIn("average turnaround", report.lower())
        self.assertIn("throughput", report.lower())
        self.assertIn("elapsed time from t=0", report.lower())
        self.assertIn("SWEEP", report)
        self.assertIn("Chosen quantum", report)
        self.assertIn("selection criterion", report.lower())

    def test_command_line_runs_cp_sweep_and_choice(self):
        completed = subprocess.run(
            [sys.executable, str(ROOT / "lab05_basic.py"), "cp"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("SWEEP", completed.stdout)
        self.assertIn("Chosen quantum", completed.stdout)
        self.assertIn("TIMELINE", completed.stdout)
        self.assertIn("average turnaround", completed.stdout.lower())


if __name__ == "__main__":
    unittest.main()
