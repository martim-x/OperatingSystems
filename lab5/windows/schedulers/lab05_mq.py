"""Deterministic, event-driven MLFQ demonstration for Windows Lab-05MQ."""

from __future__ import annotations

import argparse
import copy
import heapq
import random
from collections import deque
from dataclasses import dataclass, field
from typing import Iterable

WEIGHTS = (50, 30, 20)
QUANTA = (15, 60, 150)
QUEUE_NAMES = ("Q0", "Q1", "Q2")
PROCESS_COUNT = 100


@dataclass
class Process:
    pid: int
    arrival: int
    cpu_total: int
    io_burst: int | None = None
    io_duration: int = 0
    initial_queue: int = 0
    kind: str = ""
    remaining_cpu: int = field(init=False)
    burst_remaining: int = field(init=False)
    queue: int = field(init=False)
    waiting: int = field(default=0, init=False)
    io_time: int = field(default=0, init=False)
    cpu_time: int = field(default=0, init=False)
    completion: int | None = field(default=None, init=False)
    turnaround: int | None = field(default=None, init=False)
    ready_since: int = field(default=0, init=False)
    final_queue: int | None = field(default=None, init=False)

    def __post_init__(self) -> None:
        if self.pid < 0 or self.arrival < 0 or self.cpu_total <= 0:
            raise ValueError("pid/arrival must be non-negative and cpu_total positive")
        if not 0 <= self.initial_queue < len(QUANTA):
            raise ValueError("initial_queue must be 0, 1, or 2")
        if self.io_burst is not None and self.io_burst <= 0:
            raise ValueError("io_burst must be positive when supplied")
        if self.io_duration < 0 or (self.io_burst is None and self.io_duration):
            raise ValueError("io_duration must be non-negative and requires io_burst")
        self.remaining_cpu = self.cpu_total
        self.burst_remaining = min(self.cpu_total, self.io_burst or self.cpu_total)
        self.queue = self.initial_queue
        self.ready_since = self.arrival


@dataclass(frozen=True)
class Event:
    time: int
    kind: str
    pid: int | None = None
    queue: int | None = None
    duration: int = 0
    detail: str = ""


@dataclass
class SimulationResult:
    processes: dict[int, Process]
    events: list[Event]
    metrics: dict[str, float | int]
    queue_metrics: dict[str, dict[str, float | int]]
    seed: int


class WeightedQueueSelector:
    def __init__(self) -> None:
        self.virtual_time = 0.0
        self._finish = [0.0, 0.0, 0.0]
        self._previous_active: frozenset[int] = frozenset()

    def select(self, active_queues: Iterable[int]) -> int:
        active = tuple(sorted(set(active_queues)))
        if not active:
            raise ValueError("cannot select from an empty set of queues")
        if any(queue not in range(len(WEIGHTS)) for queue in active):
            raise ValueError("active queue indices must be 0, 1, or 2")
        for queue in range(len(WEIGHTS)):
            if queue not in self._previous_active:
                self._finish[queue] = self.virtual_time
        self._previous_active = frozenset(active)
        return min(active, key=lambda queue: (self._finish[queue], queue))

    def account(self, queue: int, duration: int, active_queues: Iterable[int]) -> None:
        active = tuple(sorted(set(active_queues)))
        if queue not in active:
            raise ValueError("the served queue must be active")
        if duration <= 0:
            raise ValueError("duration must be positive")
        total_weight = sum(WEIGHTS[item] for item in active)
        self._finish[queue] += duration / WEIGHTS[queue]
        self.virtual_time += duration / total_weight


def generate_processes(seed: int = 42) -> list[Process]:
    rng = random.Random(seed)
    types = ["CPU-bound"] * 60 + ["I/O-bound"] * 40
    rng.shuffle(types)
    processes: list[Process] = []
    for pid, kind in enumerate(types, start=1):
        arrival = rng.randint(0, 250)
        if kind == "CPU-bound":
            processes.append(Process(pid, arrival, rng.randint(300, 900), kind=kind))
        else:
            processes.append(Process(
                pid,
                arrival,
                rng.randint(100, 350),
                io_burst=rng.randint(10, 35),
                io_duration=rng.randint(20, 80),
                kind=kind,
            ))
    return sorted(processes, key=lambda process: (process.arrival, process.pid))


def simulate(processes: Iterable[Process], seed: int = 42) -> SimulationResult:
    tasks = [copy.deepcopy(process) for process in processes]
    if len({process.pid for process in tasks}) != len(tasks):
        raise ValueError("process IDs must be unique")
    tasks.sort(key=lambda process: (process.arrival, process.pid))
    by_pid = {process.pid: process for process in tasks}
    ready = [deque() for _ in QUANTA]
    io_waiting: list[tuple[int, int, int]] = []
    events: list[Event] = []
    selector = WeightedQueueSelector()
    rng = random.Random(seed)
    now = 0
    next_arrival = 0
    io_order = 0
    last_pid: int | None = None

    while any(process.completion is None for process in tasks):
        while io_waiting and io_waiting[0][0] <= now:
            return_time, _, pid = heapq.heappop(io_waiting)
            process = by_pid[pid]
            old_queue = process.queue
            process.queue = max(0, old_queue - 1)
            process.burst_remaining = min(process.remaining_cpu, process.io_burst or process.remaining_cpu)
            process.ready_since = return_time
            ready[process.queue].append(pid)
            events.append(Event(return_time, "io_complete", pid, process.queue, detail=f"Q{old_queue}->Q{process.queue}"))

        while next_arrival < len(tasks) and tasks[next_arrival].arrival <= now:
            process = tasks[next_arrival]
            process.ready_since = process.arrival
            ready[process.queue].append(process.pid)
            events.append(Event(process.arrival, "arrival", process.pid, process.queue))
            next_arrival += 1

        active = tuple(queue for queue, entries in enumerate(ready) if entries)
        if not active:
            future = []
            if next_arrival < len(tasks):
                future.append(tasks[next_arrival].arrival)
            if io_waiting:
                future.append(io_waiting[0][0])
            if not future:
                raise RuntimeError("unfinished processes have no future event")
            next_time = min(future)
            if next_time > now:
                events.append(Event(now, "idle", duration=next_time - now))
                now = next_time
            continue

        queue = selector.select(active)
        pid = ready[queue].popleft()
        process = by_pid[pid]
        wait = now - process.ready_since
        process.waiting += wait
        events.append(Event(now, "ready_wait", pid, queue, duration=wait))
        if last_pid is not None and last_pid != pid:
            events.append(Event(now, "context_switch", pid, queue, detail=f"{last_pid}->{pid}"))
        last_pid = pid
        events.append(Event(now, "dispatch", pid, queue))

        duration = min(QUANTA[queue], process.remaining_cpu, process.burst_remaining)
        if duration <= 0:
            raise RuntimeError(f"process {pid} has no runnable CPU burst")
        events.append(Event(now, "cpu_run", pid, queue, duration=duration))
        selector.account(queue, duration, active)
        now += duration
        process.cpu_time += duration
        process.remaining_cpu -= duration
        process.burst_remaining -= duration

        if process.remaining_cpu == 0:
            process.completion = now
            process.turnaround = now - process.arrival
            process.final_queue = queue
            events.append(Event(now, "finish", pid, queue))
            continue

        if process.io_burst is not None and process.burst_remaining == 0:
            process.io_time += process.io_duration
            io_order += 1
            heapq.heappush(io_waiting, (now + process.io_duration, io_order, pid))
            events.append(Event(now, "io_start", pid, queue, duration=process.io_duration))
            continue

        if duration == QUANTA[queue]:
            old_queue = queue
            process.ready_since = now
            if queue < 2:
                process.queue = queue + 1
            else:
                process.queue = rng.choice((0, 1, 2))
            events.append(Event(now, "queue_transition", pid, process.queue,
                                detail=f"Q{old_queue}->Q{process.queue}"))
            if old_queue == 2 and process.queue == 2:
                ready[2].appendleft(pid)
            else:
                ready[process.queue].append(pid)
        else:
            raise RuntimeError(f"process {pid} stopped before completion, I/O, or quantum expiry")

    total_execution = sum(event.duration for event in events if event.kind == "cpu_run")
    waiting_total = sum(event.duration for event in events if event.kind == "ready_wait")
    completed = [process for process in tasks if process.completion is not None]
    completion_time = max((process.completion or 0 for process in completed), default=0)
    dispatches = [event.pid for event in events if event.kind == "dispatch"]
    context_switches = sum(left != right for left, right in zip(dispatches, dispatches[1:]))
    turnaround_total = sum(process.turnaround or 0 for process in completed)
    transitions = sum(event.kind == "queue_transition" for event in events)
    metrics: dict[str, float | int] = {
        "completed": len(completed),
        "avg_waiting": waiting_total / len(completed) if completed else 0.0,
        "avg_turnaround": turnaround_total / len(completed) if completed else 0.0,
        "total_execution": total_execution,
        "context_switches": context_switches,
        "cpu_utilization": total_execution / completion_time if completion_time else 0.0,
        "queue_transitions": transitions,
        "throughput": len(completed) / completion_time if completion_time else 0.0,
        "simulation_end_time": completion_time,
    }
    queue_metrics: dict[str, dict[str, float | int]] = {}
    for queue, name in enumerate(QUEUE_NAMES):
        cohort = [process for process in completed if process.final_queue == queue]
        queue_metrics[name] = {
            "completed": len(cohort),
            "avg_waiting": sum(process.waiting for process in cohort) / len(cohort) if cohort else 0.0,
            "avg_turnaround": sum(process.turnaround or 0 for process in cohort) / len(cohort) if cohort else 0.0,
        }
    return SimulationResult(by_pid, events, metrics, queue_metrics, seed)


def format_summary(result: SimulationResult, full: bool = False) -> str:
    lines = [
        "Lab-05MQ — Multilevel Feedback Queue scheduler",
        f"Seed: {result.seed}",
        "Workload: 100 tasks; 60% CPU-bound, 40% I/O-bound; arrivals 0–250 ms",
        "Ranges: CPU-bound CPU 300–900 ms; I/O-bound CPU 100–350 ms, CPU burst 10–35 ms, I/O 20–80 ms",
        "Policy: Q0 RR 15 ms (50), Q1 RR 60 ms (30), Q2 FCFS 150 ms (20); weights divide runnable CPU time",
        "I/O return promotes one level; Q0 remains Q0. Q0/Q1 quantum expiry demotes; Q2 expiry equally chooses Q0/Q1/Q2 by seed.",
        f"Processes completed: {result.metrics['completed']}/{PROCESS_COUNT if result.metrics['completed'] == PROCESS_COUNT else len(result.processes)}",
        "Queue completion cohorts (average ready-wait / turnaround, ms):",
    ]
    for name, stats in result.queue_metrics.items():
        lines.append(
            f"  {name}: n={stats['completed']}, wait={stats['avg_waiting']:.2f}, "
            f"turnaround={stats['avg_turnaround']:.2f}"
        )
    metrics = result.metrics
    lines.extend([
        "System: "
        f"avg_wait={metrics['avg_waiting']:.2f} ms, "
        f"avg_turnaround={metrics['avg_turnaround']:.2f} ms, "
        f"total_execution={metrics['total_execution']} ms, "
        f"context_switches={metrics['context_switches']}, "
        f"CPU_utilization={metrics['cpu_utilization'] * 100:.2f}%, "
        f"throughput={metrics['throughput']:.4f} tasks/ms, "
        f"queue_transitions={metrics['queue_transitions']}, "
        f"end_time={metrics['simulation_end_time']} ms",
    ])
    if full:
        lines.extend([
            "Processes (PID, arrival, execution, waiting, turnaround, I/O, final queue, type):",
        ])
        for process in sorted(result.processes.values(), key=lambda item: item.pid):
            kind = process.kind or ("I/O-bound" if process.io_burst is not None else "CPU-bound")
            lines.append(
                f"PID {process.pid:03d}: arrival={process.arrival} ms, "
                f"execution={process.cpu_time} ms, waiting={process.waiting} ms, "
                f"turnaround={process.turnaround} ms, io={process.io_time} ms, "
                f"final=Q{process.final_queue}, type={kind}"
            )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run the seeded Lab-05MQ MLFQ simulation")
    parser.add_argument("--seed", type=int, default=42, help="reproducible workload and Q2 transitions (default: 42)")
    parser.add_argument("--full", action="store_true", help="include metrics for every process")
    args = parser.parse_args(argv)
    result = simulate(generate_processes(args.seed), seed=args.seed)
    print(format_summary(result, full=args.full))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
