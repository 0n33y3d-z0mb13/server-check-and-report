#!/bin/bash

# UTF-8 설정
export LANG=C.UTF-8

# 로그 디렉토리 및 파일 설정
NOW=$(date "+%Y-%m-%d_%H%M%S")
LOG_DIR="/var/log/server_check"
LOG_FILE="$LOG_DIR/$NOW.log"
mkdir -p "$LOG_DIR"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "[리포트 생성 시각]"
log "시각: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

# [서버 기본 정보]
HOSTNAME=$(hostname)
OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
OS_VERSION=$(uname -r)
UPTIME=$(uptime -p)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')

log "[서버 기본 정보]"
log "호스트명: $HOSTNAME"
log "OS: $OS_NAME"
log "커널 버전: $OS_VERSION"
log "업타임: $UPTIME"
log "IP 주소: $IP"
log ""

# [CPU]
CPU_LINE=$(top -bn1 | grep "%Cpu(s)")
CPU_IDLE=$(echo "$CPU_LINE" | awk -F',' '{for (i=1; i<=NF; i++) if ($i ~ /id/) print $i}' | awk '{print $1}')
CPU_USED=$(awk "BEGIN {printf \"%.1f\", 100 - $CPU_IDLE}")
log "[CPU]"
log "사용률: $CPU_USED %"
log ""

# [메모리]
TOTAL=$(free -m | awk '/Mem:/ {print $2}')
USED=$(free -m | awk '/Mem:/ {print $3}')
PERCENT=$(awk "BEGIN {printf \"%.1f\", $USED/$TOTAL * 100}")
log "[메모리]"
log "총 메모리: ${TOTAL} MB"
log "사용 중: ${USED} MB"
log "사용률: ${PERCENT} %"
log ""

# [디스크 - 루트(/)]
DISK_INFO=$(df -h / | awk 'NR==2')
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')
log "[디스크 - 루트(/)]"
log "총 용량: $DISK_TOTAL"
log "사용 중: $DISK_USED"
log "사용률: $DISK_PERCENT %"
log ""

# [서비스 상태]
SERVICES=("nginx" "sshd" "cron" "mysql") # 필요에 따라 수정
log "[서비스 상태]"
for svc in "${SERVICES[@]}"; do
    if systemctl list-units --type=service | grep -q "$svc"; then
        STATUS=$(systemctl is-active "$svc")
        log "$svc: $STATUS"
    elif service "$svc" status &>/dev/null; then
        STATUS=$(service "$svc" status | grep -q running && echo "active" || echo "inactive")
        log "$svc: $STATUS"
    else
        log "$svc: 미설치 또는 찾을 수 없음"
    fi
done
log ""

# [자동 시작 서비스 중 중지된 항목]
log "[자동 시작 서비스 중 중지된 항목]"
AUTOSTART_DOWN=$(systemctl list-units --type=service --state=inactive | grep enabled | awk '{print $1}')
if [ -z "$AUTOSTART_DOWN" ]; then
    log "모든 자동 시작 서비스가 실행 중입니다."
else
    echo "$AUTOSTART_DOWN" | while read svc; do
        log "$svc: 중지됨"
    done
fi
log ""

# [디스크 용량 경고]
log "[디스크 용량 경고]"
if [ "$DISK_PERCENT" -ge 90 ]; then
    log "루트(/) 디스크 사용률 경고: $DISK_PERCENT %"
else
    log "루트(/) 디스크 용량 정상: $DISK_PERCENT %"
fi
log ""

# [로그인 실패]
log "[로그인 실패]"
FAILED_LOGINS=$( (grep "Failed password" /var/log/auth.log 2>/dev/null; grep "Failed password" /var/log/secure 2>/dev/null) | tail -n 5)
if [ -z "$FAILED_LOGINS" ]; then
    log "최근 로그인 실패 기록 없음"
else
    echo "$FAILED_LOGINS" | while read line; do
        log "$(echo "$line" | cut -c1-100)..."
    done
fi
log ""

# [시스템 에러 로그]
log "[시스템 에러 로그]"
if command -v journalctl &>/dev/null; then
    ERROR_LOGS=$(journalctl -p err -n 5 2>/dev/null)
else
    ERROR_LOGS=$(grep -i "error" /var/log/messages 2>/dev/null | tail -n 5)
fi
if [ -z "$ERROR_LOGS" ]; then
    log "최근 시스템 에러 없음"
else
    echo "$ERROR_LOGS" | while read line; do
        log "$(echo "$line" | cut -c1-100)..."
    done
fi
log ""

log "[점검 상태]"
log "점검 완료"
