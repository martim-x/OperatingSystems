kill $(cat /tmp/px.pid) 2>/dev/null; sleep 1; ps -p $(cat /tmp/px.pid) >/dev/null 2>&1 && echo "процесс ещё жив" || echo "процесс завершён"
