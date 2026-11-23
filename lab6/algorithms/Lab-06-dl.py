from resources import DEADLOCK, detect


def main():
    allocation, requests, available = DEADLOCK
    print('Lab-06-dl | RS1 RS2 RS3 RS4 RS5')
    for i, (held, pending) in enumerate(zip(allocation, requests, strict=True), 1):
        print(f'P{i}: allocation={held}; request={pending}')
    trace = detect(allocation, requests, available)
    print(f'Initial Work = {trace.work[0]}')
    for i, work in zip(trace.order, trace.work[1:], strict=True):
        print(f'P{i + 1} finishes; Work = {work}')
    print('Deadlocked:', ', '.join(f'P{i + 1}' for i in trace.blocked) or 'none')


if __name__ == '__main__':
    main()
