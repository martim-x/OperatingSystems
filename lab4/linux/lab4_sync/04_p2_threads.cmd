./Lab-04p2 1 1 20000000 > /tmp/p2.out 2>&1 & pid=$!; sleep 1; echo "PID=$pid"; ps -L -p $pid; echo; grep Threads /proc/$pid/status; wait $pid; cat /tmp/p2.out
