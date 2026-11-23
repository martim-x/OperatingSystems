
"""Small, deterministic CPU scheduling simulations for Lab 05 (Windows CLI)."""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class Job:
    pid: int
    arrival: int
    burst: int
    priority: int = 0


@dataclass(frozen=True)
class Segment:
    pid: int | None
    start: int
    end: int


@dataclass(frozen=True)
class ProcessResult:
    pid: int
    arrival: int
    burst: int
    priority: int
    start: int
    finish: int
    waiting: int
    service: int
    turnaround: int


@dataclass(frozen=True)
class Metrics:
    average_waiting: float
    average_service: float
    average_turnaround: float
    throughput: float


@dataclass(frozen=True)
class Simulation:
    algorithm: str
    rows: tuple[ProcessResult, ...]
    timeline: tuple[Segment, ...]
    metrics: Metrics
    quantum: int | None = None


QUANTUM_CANDIDATES = (10, 20, 30, 45)
DEFAULT_JOBS = (
    Job(1, 0, 80, 3), Job(2, 20, 45, 5), Job(3, 30, 60, 2),
    Job(4, 50, 30, 4), Job(5, 70, 90, 1), Job(6, 100, 55, 3),
    Job(7, 120, 75, 2), Job(8, 150, 40, 5), Job(9, 180, 65, 4),
    Job(10, 200, 85, 1),
)


def _validate_jobs(jobs: Iterable[Job]) -> tuple[Job, ...]:
    items = tuple(jobs)
    seen: set[int] = set()
    for item in items:
        if not isinstance(item, Job):
            raise ValueError("each task must be a Job")
        if isinstance(item.pid, bool) or not isinstance(item.pid, int) or item.pid < 0:
            raise ValueError("task IDs must be non-negative integers")
        if item.pid in seen:
            raise ValueError(f"duplicate task ID: {item.pid}")
        seen.add(item.pid)
        if isinstance(item.arrival, bool) or not isinstance(item.arrival, int) or item.arrival < 0:
            raise ValueError("arrival times must be non-negative integers")
        if isinstance(item.burst, bool) or not isinstance(item.burst, int) or item.burst <= 0:
            raise ValueError("burst times must be positive integers")
        if isinstance(item.priority, bool) or not isinstance(item.priority, int):
            raise ValueError("priorities must be integers")
    return items


def _validate_quantum(quantum: int) -> None:
    if isinstance(quantum, bool) or not isinstance(quantum, int) or quantum <= 0:
        raise ValueError("quantum must be a positive integer")


def _append_segment(timeline: list[Segment], pid: int | None, start: int, end: int) -> None:
    if start == end:
        return
    if timeline and timeline[-1].pid == pid and timeline[-1].end == start:
        previous = timeline[-1]
        timeline[-1] = Segment(pid, previous.start, end)
    else:
        timeline.append(Segment(pid, start, end))


def _finish_result(algorithm: str, jobs: tuple[Job, ...], starts: dict[int, int],
                   finishes: dict[int, int], timeline: list[Segment],
                   quantum: int | None = None) -> Simulation:
    rows = tuple(
        ProcessResult(job.pid, job.arrival, job.burst, job.priority, starts[job.pid],
                      finishes[job.pid], finishes[job.pid] - job.arrival - job.burst,
                      job.burst, finishes[job.pid] - job.arrival)
        for job in jobs
    )
    count = len(rows)
    elapsed = max(finishes.values(), default=0)
    metrics = Metrics(
        sum(row.waiting for row in rows) / count if count else 0.0,
        sum(row.service for row in rows) / count if count else 0.0,
        sum(row.turnaround for row in rows) / count if count else 0.0,
        count / elapsed if elapsed else 0.0,
    )
    return Simulation(algorithm, rows, tuple(timeline), metrics, quantum)


def simulate_sjf(jobs: Iterable[Job] = DEFAULT_JOBS) -> Simulation:
    """Non-preemptive SJF; equal bursts use earlier arrival, then input order."""
    items = _validate_jobs(jobs)
    pending = sorted(enumerate(items), key=lambda pair: (pair[1].arrival, pair[0]))
    complete: set[int] = set()
    starts: dict[int, int] = {}
    finishes: dict[int, int] = {}
    timeline: list[Segment] = []
    now = 0
    while len(complete) < len(items):
        available = [(i, job) for i, job in enumerate(items)
                     if i not in complete and job.arrival <= now]
        if not available:
            next_time = min(job.arrival for i, job in pending if i not in complete)
            _append_segment(timeline, None, now, next_time)
            now = next_time
            continue
        index, current = min(available, key=lambda pair:
                            (pair[1].burst, pair[1].arrival, pair[0]))
        starts[current.pid] = now
        now += current.burst
        finishes[current.pid] = now
        complete.add(index)
        _append_segment(timeline, current.pid, starts[current.pid], now)
    return _finish_result("SJF", items, starts, finishes, timeline)


def simulate_rr(jobs: Iterable[Job] = DEFAULT_JOBS, quantum: int = 10) -> Simulation:
    """Round Robin; arrivals at a slice boundary queue before the expired task."""
    _validate_quantum(quantum)
    items = _validate_jobs(jobs)
    pending = sorted(enumerate(items), key=lambda pair: (pair[1].arrival, pair[0]))
    ready: deque[int] = deque()
    remaining = [job.burst for job in items]
    starts: dict[int, int] = {}
    finishes: dict[int, int] = {}
    timeline: list[Segment] = []
    next_arrival = 0
    now = 0

    def enqueue_arrivals(through: int) -> None:
        nonlocal next_arrival
        while next_arrival < len(pending) and pending[next_arrival][1].arrival <= through:
            ready.append(pending[next_arrival][0])
            next_arrival += 1

    while len(finishes) < len(items):
        enqueue_arrivals(now)
        if not ready:
            next_time = pending[next_arrival][1].arrival
            _append_segment(timeline, None, now, next_time)
            now = next_time
            enqueue_arrivals(now)
        index = ready.popleft()
        current = items[index]
        starts.setdefault(current.pid, now)
        end = now + min(quantum, remaining[index])
        _append_segment(timeline, current.pid, now, end)
        remaining[index] -= end - now
        now = end
        enqueue_arrivals(now)
        if remaining[index] == 0:
            finishes[current.pid] = now
        else:
            ready.append(index)
    return _finish_result("RR", items, starts, finishes, timeline, quantum)


def simulate_cp(jobs: Iterable[Job] = DEFAULT_JOBS, quantum: int = 10) -> Simulation:
    """Preemptive priority; higher numbers win and equal priorities use RR.

    Strictly higher-priority arrivals preempt immediately. Equal-priority
    arrivals wait for the current slice. Arrival ties use input order. A
    preempted task keeps the front of its own priority queue; quantum expiry
    rotates the task to that queue's tail.
    """
    _validate_quantum(quantum)
    items = _validate_jobs(jobs)
    pending = sorted(enumerate(items), key=lambda pair: (pair[1].arrival, pair[0]))
    ready: dict[int, deque[int]] = {}
    remaining = [job.burst for job in items]
    starts: dict[int, int] = {}
    finishes: dict[int, int] = {}
    timeline: list[Segment] = []
    next_arrival = 0
    now = 0

    def enqueue_arrivals(through: int) -> None:
        nonlocal next_arrival
        while next_arrival < len(pending) and pending[next_arrival][1].arrival <= through:
            index, job = pending[next_arrival]
            ready.setdefault(job.priority, deque()).append(index)
            next_arrival += 1

    while len(finishes) < len(items):
        enqueue_arrivals(now)
        if not any(ready.values()):
            next_time = pending[next_arrival][1].arrival
            _append_segment(timeline, None, now, next_time)
            now = next_time
            enqueue_arrivals(now)
        priority = max(value for value, queue in ready.items() if queue)
        index = ready[priority].popleft()
        current = items[index]
        starts.setdefault(current.pid, now)
        slice_end = now + min(quantum, remaining[index])
        preempt_at = next((job.arrival for _, job in pending[next_arrival:]
                           if now < job.arrival < slice_end and job.priority > priority), None)
        end = preempt_at if preempt_at is not None else slice_end
        _append_segment(timeline, current.pid, now, end)
        remaining[index] -= end - now
        now = end
        enqueue_arrivals(now)
        if remaining[index] == 0:
            finishes[current.pid] = now
        elif preempt_at is not None:
            ready.setdefault(priority, deque()).appendleft(index)
        else:
            ready.setdefault(priority, deque()).append(index)
    return _finish_result("CP", items, starts, finishes, timeline, quantum)


def select_quantum(results: Iterable[Simulation]) -> Simulation:
    """Choose minimum average waiting; then fewer slices, then larger quantum."""
    candidates = tuple(results)
    if not candidates:
        raise ValueError("at least one quantum result is required")
    return min(candidates, key=lambda result:
               (result.metrics.average_waiting, len(result.timeline), -(result.quantum or 0)))


def _format_input(jobs: tuple[Job, ...]) -> str:
    lines = ["INPUT: id  arrival  burst  priority"]
    lines.extend(f"      {job.pid:>2}  {job.arrival:>7}  {job.burst:>5}  {job.priority:>8}"
                 for job in jobs)
    return "\n".join(lines)


def _format_results(result: Simulation) -> str:
    lines = ["RESULTS: id  arrival  burst  prio  start  finish  wait  service  turn"]
    lines.extend(
        f"        {row.pid:>2}  {row.arrival:>7}  {row.burst:>5}  {row.priority:>4}"
        f"  {row.start:>5}  {row.finish:>6}  {row.waiting:>4}  {row.service:>7}"
        f"  {row.turnaround:>4}"
        for row in result.rows
    )
    return "\n".join(lines)


def _format_metrics(metrics: Metrics) -> str:
    return (f"Metrics: average waiting={metrics.average_waiting:.2f}, "
            f"average service={metrics.average_service:.2f}, "
            f"average turnaround={metrics.average_turnaround:.2f}, "
            f"throughput={metrics.throughput:.4f} tasks/time-unit\n"
            "Metric formulas: average waiting=mean(finish-arrival-burst); "
            "average service=mean(burst); average turnaround=mean(finish-arrival); "
            "throughput=task count / elapsed time from t=0 to last finish.")


def _format_timeline(result: Simulation, per_line: int = 10) -> str:
    parts = [f"{part.start}-{part.end}:{'IDLE' if part.pid is None else f'P{part.pid}'}"
             for part in result.timeline]
    lines = ["TIMELINE:"]
    lines.extend("  " + " | ".join(parts[i:i + per_line])
                 for i in range(0, len(parts), per_line))
    if not parts:
        lines.append("  (empty schedule)")
    return "\n".join(lines)


def format_report(algorithm: str, jobs: Iterable[Job] = DEFAULT_JOBS, *, quantum: int | None = None) -> str:
    """Render input/results, schedule, four metrics and RR/CP quantum sweep."""
    items = _validate_jobs(jobs)
    name = algorithm.lower()
    if name not in {"sjf", "rr", "cp"}:
        raise ValueError("algorithm must be sjf, rr, or cp")
    lines = [_format_input(items), ""]
    if name == "sjf":
        if quantum is not None:
            raise ValueError("SJF has no quantum")
        result = simulate_sjf(items)
        lines.extend((_format_results(result), _format_metrics(result.metrics),
                      _format_timeline(result)))
        lines.append("Selection criterion: non-preemptive shortest burst; ties by arrival then input order.")
        lines.append(f"Simulation completion time: {max((row.finish for row in result.rows), default=0)} time units")
        return "\n".join(lines)

    simulator = simulate_rr if name == "rr" else simulate_cp
    if quantum is not None:
        result = simulator(items, quantum=quantum)
        lines.extend((f"Single-quantum run: {quantum}", _format_results(result), _format_metrics(result.metrics),
                      _format_timeline(result)))
        lines.append(f"Simulation completion time: {max((row.finish for row in result.rows), default=0)} time units")
        return "\n".join(lines)
    results = tuple(simulator(items, quantum=q) for q in QUANTUM_CANDIDATES)
    chosen = select_quantum(results)
    lines.append("SWEEP: quantum  avg_wait  avg_service  avg_turnaround  throughput  segments")
    lines.extend(
        f"       {result.quantum:>7}  {result.metrics.average_waiting:>8.2f}"
        f"  {result.metrics.average_service:>11.2f}"
        f"  {result.metrics.average_turnaround:>14.2f}"
        f"  {result.metrics.throughput:>10.4f}  {len(result.timeline):>6}"
        for result in results
    )
    lines.append(f"Chosen quantum: {chosen.quantum}")
    lines.append("Selection criterion: minimum average waiting, then fewer timeline segments, then larger quantum.")
    lines.extend((_format_results(chosen), _format_metrics(chosen.metrics),
                  _format_timeline(chosen)))
    lines.append(f"Simulation completion time: {max((row.finish for row in chosen.rows), default=0)} time units")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("algorithm", choices=("sjf", "rr", "cp"))
    parser.add_argument("--quantum", type=int, help="run RR or CP with a single quantum")
    args = parser.parse_args(argv)
    if args.quantum is not None and (args.algorithm == "sjf" or args.quantum <= 0):
        parser.error("--quantum must be positive and is only valid for RR and CP")
    print(format_report(args.algorithm, quantum=args.quantum))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
