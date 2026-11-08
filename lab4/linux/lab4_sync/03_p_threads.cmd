./Lab-04p 1 1 20000000 > /tmp/p.out 2>&1 & pid=$!; sleep 1; echo "PID=$pid"; ps -L -p $pid; echo; grep Threads /proc/$pid/status; wait $pid; cat /tmp/p.out
