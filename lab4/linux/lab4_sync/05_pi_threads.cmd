./Lab-04pi 4 > /tmp/pi.out 2>&1 & pid=$!; sleep 2; echo "PID=$pid"; ps -L -p $pid; echo; grep Threads /proc/$pid/status; kill -INT $pid; sleep 1; cat /tmp/pi.out
