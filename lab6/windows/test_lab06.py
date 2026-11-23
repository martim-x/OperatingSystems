"""Integration checks for Lab-06a/b/c/d (delay override is test-only)."""
from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

ITER_RE = re.compile(r"^ITER role=(\w+) pid=(\d+) tid=(\d+) iteration=(\d+) user=(.)$")
BOUNDARY_RE = re.compile(r"^(ENTER|LEAVE) role=(\w+) iteration=(\d+)$")
TOTALS = {"Lab-06a": 100, "Lab-06b": 100, "Lab-06c": 100, "Lab-06d": 1000}
USER_NAME = "User-6d4ec851"


def verify_run(executable: Path, log_path: Path, total: int, default_delay: bool) -> None:
    arguments = [str(executable)]
    if not default_delay:
        arguments.extend(["--test-delay-ms", "0"])
    arguments.extend(["--log-file", str(log_path)])
    result = subprocess.run(
        arguments,
        text=True,
        capture_output=True,
        timeout=240,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"{executable.name} exited {result.returncode}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )

    lines = log_path.read_text(encoding="ascii").splitlines()
    iterations: dict[str, list[int]] = {}
    identities: dict[str, set[tuple[str, str]]] = {}
    owner: str | None = None
    entered_roles: set[str] = set()
    left_roles: set[str] = set()
    event_set_index: int | None = None
    parent_15_index: int | None = None
    parent_16_index: int | None = None
    first_child_index: int | None = None

    for index, line in enumerate(lines):
        if line == "EVENT_SET":
            if event_set_index is not None:
                raise AssertionError("event was signalled more than once")
            event_set_index = index
            continue
        match = ITER_RE.match(line)
        if match:
            role, pid, tid, iteration_text, user_char = match.groups()
            iteration = int(iteration_text)
            if user_char != USER_NAME[(iteration - 1) % len(USER_NAME)]:
                raise AssertionError(f"wrong user character in {role} iteration {iteration}: {user_char!r}")
            iterations.setdefault(role, []).append(iteration)
            identities.setdefault(role, set()).add((pid, tid))
            if executable.stem != "Lab-06d" and 30 <= iteration <= 60 and role != owner:
                raise AssertionError(f"unprotected iteration {role}:{iteration} (owner={owner})")
            if role == "MAIN" and iteration == 15:
                parent_15_index = index
            if role == "MAIN" and iteration == 16:
                parent_16_index = index
            if role in ("A", "B") and first_child_index is None:
                first_child_index = index
            continue
        match = BOUNDARY_RE.match(line)
        if match:
            boundary, role, iteration_text = match.groups()
            iteration = int(iteration_text)
            if executable.stem == "Lab-06d":
                raise AssertionError("Lab-06d must use the event, not critical-section boundaries")
            if boundary == "ENTER":
                if iteration != 30 or owner is not None:
                    raise AssertionError(f"invalid/overlapping critical interval: {line}; owner={owner}")
                owner = role
                entered_roles.add(role)
            else:
                if iteration != 60 or owner != role:
                    raise AssertionError(f"unmatched critical-section leave: {line}; owner={owner}")
                owner = None
                left_roles.add(role)

    if owner is not None:
        raise AssertionError(f"critical section left occupied by {owner}")
    expected_roles = {"MAIN", "A", "B"}
    if set(iterations) != expected_roles:
        raise AssertionError(f"expected roles {expected_roles}, got {set(iterations)}")
    for role, sequence in iterations.items():
        if sequence != list(range(1, total + 1)):
            raise AssertionError(f"{role}: expected iterations 1..{total}, got {len(sequence)} / {sequence[:5]}")
        if len(identities[role]) != 1:
            raise AssertionError(f"{role} output came from multiple process/thread identities: {identities[role]}")

    if executable.stem == "Lab-06a":
        pids = {next(iter(identity))[0] for identity in identities.values()}
        tids = {next(iter(identity))[1] for identity in identities.values()}
        if len(pids) != 1 or len(tids) != 3:
            raise AssertionError(f"Lab-06a must use three distinct threads in one process: {identities}")
    else:
        pids = {next(iter(identity))[0] for identity in identities.values()}
        if len(pids) != 3:
            raise AssertionError(f"{executable.name} must use three separate processes: {identities}")

    if executable.stem == "Lab-06d":
        if event_set_index is None or parent_15_index is None or parent_16_index is None or first_child_index is None:
            raise AssertionError("missing parent pre-signal phase or child output")
        if not parent_15_index < event_set_index < parent_16_index:
            raise AssertionError("event must be signalled between the parent's 15th and 16th iterations")
        if event_set_index >= first_child_index:
            raise AssertionError("a child ran before the parent signalled at iteration 16")
    else:
        if event_set_index is not None:
            raise AssertionError(f"unexpected EVENT_SET in {executable.name}")
        expected_roles = {"MAIN", "A", "B"}
        if entered_roles != expected_roles or left_roles != expected_roles:
            raise AssertionError(f"not all roles completed one exclusive 30..60 interval: enter={entered_roles}, leave={left_roles}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tools", type=Path, default=Path(__file__).parent / "tools")
    parser.add_argument(
        "--default",
        action="store_true",
        help="run at the required 100 ms delay instead of the test-only zero-delay override",
    )
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="lab06-verify-") as temp:
        temp_path = Path(temp)
        for name, total in TOTALS.items():
            executable = args.tools / f"{name}.exe"
            log_path = temp_path / f"{name}.log"
            verify_run(executable, log_path, total, args.default)
            mode = "default 100 ms" if args.default else "test-only 0 ms"
            print(f"PASS {name}: {mode}; MAIN/A/B each completed {total} iterations; synchronization verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
