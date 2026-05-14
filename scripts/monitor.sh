# 0. 환경 설정
LOG_FILE="/var/log/agent-app/monitor.log"
APP_NAME="agent-app"
PORT=15034
MAX_SIZE=10485760  # 10MB
MAX_FILES=10

# 1. Health Check (실패 시 종료)
PID=$(pgrep -f "$APP_NAME" | head -n 1)
if [ -z "$PID" ]; then
    echo "[ERROR] Process $APP_NAME is not running."
    exit 1
fi

if ! ss -tuln | grep -q ":$PORT "; then
    echo "[ERROR] Port $PORT is not listening."
    exit 1
fi

# 2. 상태 점검 (경고만 출력)
if ! command -v ufw > /dev/null || ! ufw status | grep -q "active"; then
    echo "[WARNING] Firewall is inactive or unreachable."
fi

# 3. 자원 수집
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
DISK_USAGE=$(df / | grep / | tail -1 | awk '{print $5}' | sed 's/%//')

# 4. 결과 출력 및 임계값 경고
echo "====== SYSTEM MONITOR RESULT ======"
echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"
echo "Checking port $PORT... [OK]"
echo ""
echo "[RESOURCE MONITORING]"
echo "CPU Usage : $CPU_USAGE%"
echo "MEM Usage : $MEM_USAGE%"
echo "DISK Used : $DISK_USAGE%"

if (( $(echo "$CPU_USAGE > 20" | awk '{print ($1 > $2)}') )); then echo "[WARNING] CPU threshold exceeded ($CPU_USAGE% > 20%)"; fi
if (( $(echo "$MEM_USAGE > 10" | awk '{print ($1 > $2)}') )); then echo "[WARNING] MEM threshold exceeded ($MEM_USAGE% > 10%)"; fi
if [ "$DISK_USAGE" -gt 80 ]; then echo "[WARNING] DISK threshold exceeded ($DISK_USAGE% > 80%)"; fi

# 5. 로그 기록
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_LINE="[$TIMESTAMP] PID:$PID CPU:$CPU_USAGE% MEM:$MEM_USAGE% DISK_USED:$DISK_USAGE%"
echo "$LOG_LINE" >> "$LOG_FILE"
echo ""
echo "[INFO] Log appended: $LOG_FILE"

# 6. 로그 파일 용량 관리 (10MB 초과 시 10개 파일 유지)
MAX_SIZE=10485760  # 10MB
MAX_FILES=10

if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_SIZE ]; then
    echo "[INFO] Log size exceeded 10MB. Rotating logs..."
    
    # 1. 가장 오래된 10번 파일은 삭제해서 자리를 만듭니다.
    rm -f "$LOG_FILE.$MAX_FILES"
    
    # 2. 파일들을 하나씩 뒤로 미룹니다 (9번은 10번으로, 1번은 2번으로...)
    # 역순으로 옮겨야 파일이 덮어씌워지지 않고 도미노처럼 밀려납니다.
    for i in $(seq $((MAX_FILES-1)) -1 1); do
        if [ -f "$LOG_FILE.$i" ]; then
            mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
        fi
    done
    
    # 3. 현재 로그를 1번으로 만들고, 새 로그 파일을 생성합니다.
    mv "$LOG_FILE" "$LOG_FILE.1"
    touch "$LOG_FILE"
    
    # 4. 권한 복구 (그룹이 계속 쓸 수 있게)
    chmod 660 "$LOG_FILE"
    chgrp agent-core "$LOG_FILE"
fi