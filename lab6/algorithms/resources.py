from dataclasses import dataclass

Vector = tuple[int, ...]
Matrix = tuple[Vector, ...]

DEADLOCK = (
    ((0, 1, 1, 1, 2), (0, 1, 0, 1, 0), (0, 0, 0, 0, 1), (2, 1, 0, 0, 0)),
    ((1, 1, 0, 2, 1), (0, 1, 0, 2, 1), (0, 2, 0, 3, 1), (0, 2, 1, 1, 0)),
    (0, 1, 0, 2, 1),
)
TASK2 = (
    ((1, 0, 2, 1, 1), (2, 0, 1, 1, 0), (1, 1, 0, 1, 0), (1, 1, 1, 1, 0)),
    ((1, 1, 2, 1, 3), (2, 2, 2, 1, 0), (2, 1, 3, 1, 0), (1, 1, 2, 2, 1)),
)
BANK = (
    ((0, 1, 0), (2, 0, 0), (3, 0, 2), (2, 1, 1), (0, 0, 2)),
    ((7, 5, 3), (3, 2, 2), (9, 0, 2), (2, 2, 2), (4, 3, 3)),
    (3, 3, 2),
)


@dataclass(frozen=True)
class Trace:
    order: tuple[int, ...]
    blocked: tuple[int, ...]
    work: tuple[Vector, ...]


@dataclass(frozen=True)
class Decision:
    status: str
    allocation: Matrix
    available: Vector
    trace: Trace | None = None


def vector(values, width):
    values = tuple(values)
    if len(values) != width or any(type(v) is not int or v < 0 for v in values):
        raise ValueError('expected a nonnegative integer resource vector of the required width')
    return values


def state(allocation, demands, available):
    available = tuple(available)
    width = len(available)
    if width == 0:
        raise ValueError('at least one resource type is required')
    allocation = tuple(vector(row, width) for row in allocation)
    demands = tuple(vector(row, width) for row in demands)
    if len(allocation) != len(demands):
        raise ValueError('process counts differ')
    return allocation, demands, vector(available, width)


def leq(left, right):
    return all(a <= b for a, b in zip(left, right, strict=True))


def add(left, right):
    return tuple(a + b for a, b in zip(left, right, strict=True))


def sub(left, right):
    return tuple(a - b for a, b in zip(left, right, strict=True))


def scan(allocation, demands, available, *, detect_only):
    done = [detect_only and not any(row) for row in allocation]
    order = []
    work = [available]
    while True:
        count = len(order)
        for pid, required in enumerate(demands):
            if not done[pid] and leq(required, work[-1]):
                work.append(add(work[-1], allocation[pid]))
                order.append(pid)
                done[pid] = True
        if count == len(order):
            return Trace(tuple(order), tuple(i for i, value in enumerate(done) if not value), tuple(work))


def detect(allocation, requests, available):
    return scan(*state(allocation, requests, available), detect_only=True)


def need(allocation, maximum):
    if any(not leq(a, m) for a, m in zip(allocation, maximum, strict=True)):
        raise ValueError('allocation cannot exceed maximum')
    return tuple(sub(m, a) for a, m in zip(allocation, maximum, strict=True))


def safety(allocation, maximum, available):
    allocation, maximum, available = state(allocation, maximum, available)
    return scan(allocation, need(allocation, maximum), available, detect_only=False)


def request(allocation, maximum, available, pid, amounts):
    allocation, maximum, available = state(allocation, maximum, available)
    if type(pid) is not int or not 0 <= pid < len(allocation):
        raise ValueError('unknown process')
    amounts = vector(amounts, len(available))
    if not leq(amounts, need(allocation, maximum)[pid]):
        return Decision('exceeds-need', allocation, available)
    if not leq(amounts, available):
        return Decision('unavailable', allocation, available)
    proposed = allocation[:pid] + (add(allocation[pid], amounts),) + allocation[pid + 1:]
    balance = sub(available, amounts)
    trace = safety(proposed, maximum, balance)
    if trace.blocked:
        return Decision('unsafe', allocation, available, trace)
    return Decision('granted', proposed, balance, trace)
