"""Behavioral tests for the Windows Lab-05MQ scheduler."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

import lab05_mq


class SchedulerTests(unittest.TestCase):
    def test_turnaround_partitions_into_cpu_io_and_ready_wait(self) -> None:
        result = lab05_mq.simulate(lab05_mq.generate_processes(42), seed=42)
        for process in result.processes.values():
            with self.subTest(pid=process.pid):
                self.assertEqual(process.turnaround, process.cpu_time + process.io_time + process.waiting)

    def test_single_process_finishes_without_wait_or_context_switch(self) -> None:
        result = lab05_mq.simulate([lab05_mq.Process(pid=1, arrival=0, cpu_total=10)])

        process = result.processes[1]
        self.assertEqual((process.completion, process.waiting, process.turnaround), (10, 0, 10))
        self.assertEqual(result.metrics["total_execution"], 10)
        self.assertEqual(result.metrics["context_switches"], 0)
        self.assertEqual(result.metrics["queue_transitions"], 0)

    def test_q0_quantum_expiry_demotes_process_to_q1(self) -> None:
        result = lab05_mq.simulate([lab05_mq.Process(pid=1, arrival=0, cpu_total=20)])

        transitions = [event for event in result.events if event.kind == "queue_transition"]
        self.assertEqual([(event.time, event.detail) for event in transitions], [(15, "Q0->Q1")])
        self.assertEqual(result.processes[1].completion, 20)

    def test_q1_quantum_expiry_demotes_process_to_q2(self) -> None:
        result = lab05_mq.simulate([lab05_mq.Process(pid=1, arrival=0, cpu_total=100)])

        transitions = [event for event in result.events if event.kind == "queue_transition"]
        self.assertEqual([(event.time, event.detail) for event in transitions], [
            (15, "Q0->Q1"),
            (75, "Q1->Q2"),
        ])
        self.assertEqual(result.processes[1].completion, 100)

    def test_completion_exactly_at_quantum_boundary_does_not_demote(self) -> None:
        result = lab05_mq.simulate([lab05_mq.Process(pid=1, arrival=0, cpu_total=15)])

        self.assertEqual(result.processes[1].completion, 15)
        self.assertFalse(any(event.kind == "queue_transition" for event in result.events))

    def test_idle_gap_advances_to_next_arrival_without_fabricating_cpu_work(self) -> None:
        result = lab05_mq.simulate([
            lab05_mq.Process(pid=1, arrival=0, cpu_total=5),
            lab05_mq.Process(pid=2, arrival=20, cpu_total=5),
        ])

        self.assertEqual(result.processes[2].completion, 25)
        self.assertEqual(result.metrics["total_execution"], 10)
        self.assertEqual(result.metrics["cpu_utilization"], 0.4)
        self.assertTrue(any(event.kind == "idle" and event.time == 5 for event in result.events))

    def test_io_completion_promotes_q1_process_to_q0(self) -> None:
        result = lab05_mq.simulate([
            lab05_mq.Process(pid=1, arrival=0, cpu_total=25, io_burst=20, io_duration=5),
        ])

        io_return = [event for event in result.events if event.kind == "io_complete"]
        self.assertEqual([(event.time, event.queue) for event in io_return], [(25, 0)])
        self.assertEqual(result.processes[1].completion, 30)
        self.assertEqual(result.processes[1].io_time, 5)

    def test_q2_transition_is_seeded_and_can_choose_each_destination(self) -> None:
        def destination(seed: int) -> str:
            result = lab05_mq.simulate(
                [lab05_mq.Process(pid=1, arrival=0, cpu_total=600, initial_queue=2)],
                seed=seed,
            )
            transition = next(event for event in result.events if event.kind == "queue_transition")
            return transition.detail

        first = destination(42)
        self.assertEqual(first, destination(42))
        observed = {destination(seed) for seed in range(12)}
        self.assertEqual(observed, {"Q2->Q0", "Q2->Q1", "Q2->Q2"})

    def test_weighted_selector_tracks_cpu_time_not_number_of_dispatches(self) -> None:
        selector = lab05_mq.WeightedQueueSelector()
        active = (0, 1, 2)
        quanta = (15, 60, 150)
        served = [0, 0, 0]
        for _ in range(4000):
            queue = selector.select(active)
            duration = quanta[queue]
            served[queue] += duration
            selector.account(queue, duration, active)

        total = sum(served)
        shares = tuple(value / total for value in served)
        self.assertAlmostEqual(shares[0], 0.5, delta=0.01)
        self.assertAlmostEqual(shares[1], 0.3, delta=0.01)
        self.assertAlmostEqual(shares[2], 0.2, delta=0.01)
        self.assertEqual(selector.select((2,)), 2)  # work-conserving

    def test_seeded_generator_produces_exactly_one_hundred_tasks(self) -> None:
        first = lab05_mq.generate_processes(seed=42)
        second = lab05_mq.generate_processes(seed=42)

        self.assertEqual(len(first), 100)
        self.assertEqual(first, second)
        self.assertEqual(sum(process.io_burst is None for process in first), 60)
        self.assertEqual(sum(process.io_burst is not None for process in first), 40)

    def test_cli_summary_is_compact_and_full_mode_lists_all_processes(self) -> None:
        script = Path(__file__).with_name("lab05_mq.py")
        compact = subprocess.run(
            [sys.executable, str(script), "--seed", "42"],
            check=True, capture_output=True, text=True,
        ).stdout
        full = subprocess.run(
            [sys.executable, str(script), "--seed", "42", "--full"],
            check=True, capture_output=True, text=True,
        ).stdout

        self.assertIn("Processes completed: 100/100", compact)
        self.assertNotIn("PID 001", compact)
        self.assertEqual(full.count("PID "), 100)
        self.assertIn("Seed: 42", compact)


if __name__ == "__main__":
    unittest.main()
