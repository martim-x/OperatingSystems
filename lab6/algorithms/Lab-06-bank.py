import argparse

from resources import BANK, TASK2, request, safety


def sequence(trace, labels):
    return ' -> '.join(labels[i] for i in trace.order) or 'none'


def main():
    parser = argparse.ArgumentParser(description='Lab-06-bank: safety and resource grants')
    options = parser.add_mutually_exclusive_group()
    options.add_argument('--request', nargs=4, type=int, metavar=('PID', 'A', 'B', 'C'))
    options.add_argument('--task2', type=int, metavar='X')
    args = parser.parse_args()
    if args.task2 is not None:
        if args.task2 < 0:
            parser.error('X must be nonnegative')
        result = safety(*TASK2, (0, 0, args.task2, 1, 1))
        print(f'Task 2: x={args.task2}; finishable: {sequence(result, "ABCD")}')
        print('The stated fifth-resource maximum of process A is 3; the total is 2, independent of x.')
        print('No nonnegative x makes this state safe.')
        return
    labels = tuple(f'P{i}' for i in range(len(BANK[0])))
    allocation, maximum, available = BANK
    if args.request is None:
        trace = safety(*BANK)
        print('Lab-06-bank | total A/B/C = (10, 5, 7)')
        print(f'Safe sequence: {sequence(trace, labels)}')
        print('Work:', *trace.work, sep=' -> ')
        return
    pid, *amounts = args.request
    try:
        decision = request(allocation, maximum, available, pid, amounts)
    except ValueError as error:
        parser.error(str(error))
    print(f'P{pid} requests {tuple(amounts)}: {decision.status}')
    print(f'Available after decision: {decision.available}')
    if decision.status == 'granted' and decision.trace is not None:
        print(f'Safe sequence: {sequence(decision.trace, labels)}')


if __name__ == '__main__':
    main()
