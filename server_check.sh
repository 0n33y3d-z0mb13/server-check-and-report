#!/bin/bash

# 공통 설정
HOSTNAME=$(hostname)
DATETIME=$(date "+%Y-%m-%d_%H%M%S")     # 파일명용
REPORT_TIME=$(date "+%Y-%m-%d %H:%M:%S") # 리포트 본문용
LOG_DIR="/var/log/server_check"
LOG_FILE="$LOG_DIR/${DATETIME}.log"
SUMMARY_MODE=false

# 옵션 처리: --summary 붙일 경우 요약본 출력
if [[ "$1" == "--summary" ]]; then
    SUMMARY_MODE=true
fi

mkdir -p "$LOG_DIR"

# 리포트 시작
if $SUMMARY_MODE; then
    echo "===== [서버 요약 보고서] $REPORT_TIME ====="
else
    echo "===== [서버 점검 리포트] $REPORT_TIME =====" > "$LOG_FILE"
fi

# 서버 기본 정보
OS_NAME=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
CPU_MODEL=$(lscpu 2>/dev/null | grep 'Model name' | awk -F: '{print $2}' | sed 's/^ *//')
UPTIME=$(uptime -p 2>/dev/null || uptime)

# IP 주소 추출 (모든 환경 대응)
if command -v hostname &> /dev/null && hostname -I &> /dev/null; then
    IP_ADDR=$(hostname -I | awk '{print $1}')
else
    IP_ADDR=$(ip addr show | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1 | head -n 1)
fi

if $SUMMARY_MODE; then
    echo "호스트명: $HOSTNAME"
    echo "OS: ${OS_NAME:-Unknown}"
    echo "Uptime: $UPTIME"
    echo "IP: $IP_ADDR"
else
    {
    echo "[서버 기본 정보]"
    echo "호스트명: $HOSTNAME"
    echo "운영 체제: ${OS_NAME:-Unknown}"
    echo "커널 버전: $KERNEL"
    echo "CPU 모델: ${CPU_MODEL:-Unknown}"
    echo "업타임: $UPTIME"
    echo "IP 주소: $IP_ADDR"
    echo ""
    } >> "$LOG_FILE"
fi

# CPU 사용률
CPU_LINE=$(top -bn1 | grep "%Cpu(s)")
CPU_IDLE=$(echo "$CPU_LINE" | awk -F',' '{for (i=1; i<=NF; i++) if ($i ~ /id/) {print $i}}' | awk '{print $1}')
CPU_USED=$(awk "BEGIN {printf \"%.1f\", 100 - $CPU_IDLE}")

if $SUMMARY_MODE; then
    echo "CPU 사용률: ${CPU_USED}%"
else
    echo "[CPU 사용률]" >> "$LOG_FILE"
    echo "CPU 사용률: ${CPU_USED}%" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi


# 메모리 사용
TOTAL=$(free -m | awk '/Mem:/ {print $2}')
USED=$(free -m | awk '/Mem:/ {print $3}')
PERCENT=$(awk "BEGIN {printf \"%.1f\", $USED/$TOTAL * 100}")

if $SUMMARY_MODE; then
    echo "메모리 사용률: $PERCENT% ($USED MB / $TOTAL MB)"
else
    echo "[메모리 사용량]" >> "$LOG_FILE"
    echo "메모리 사용률: $PERCENT% ($USED MB / $TOTAL MB)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

# 디스크 사용률 (요약 모드: %만, 전체 모드: 퍼센트 + 용량)
DISK_INFO=$(df -h / | awk 'NR==2')
DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}')
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}')
DISK_PERCENT=$(echo "$DISK_INFO" | awk '{print $5}')

if $SUMMARY_MODE; then
    echo "디스크 사용률 (/): $DISK_PERCENT"
else
    echo "[디스크 사용량 - 루트(/)]" >> "$LOG_FILE"
    echo "총 용량: $DISK_TOTAL, 사용 중: $DISK_USED, 사용률: $DISK_PERCENT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

# 서비스 상태 확인 (systemctl or service)
SERVICE_FOUND=false

if $SUMMARY_MODE; then
    echo "서비스 상태:"
    for service in "${SERVICES[@]}"; do
        if pidof systemd &>/dev/null && systemctl list-units --type=service | grep -q "$service"; then
            STATUS=$(systemctl is-active "$service")
            echo " - $service: $STATUS"
            SERVICE_FOUND=true
        elif service "$service" status &>/dev/null; then
            STATUS=$(service "$service" status | grep -q running && echo "active" || echo "inactive")
            echo " - $service: $STATUS"
            SERVICE_FOUND=true
        fi
    done
    if ! $SERVICE_FOUND; then
        echo " - 점검 대상 서비스 없음"
    fi
else
    echo "[서비스 상태]" >> "$LOG_FILE"
    for service in "${SERVICES[@]}"; do
        if pidof systemd &>/dev/null && systemctl list-units --type=service | grep -q "$service"; then
            STATUS=$(systemctl is-active "$service")
            echo "$service: $STATUS" >> "$LOG_FILE"
            SERVICE_FOUND=true
        elif service "$service" status &>/dev/null; then
            STATUS=$(service "$service" status | grep -q running && echo "active" || echo "inactive")
            echo "$service: $STATUS" >> "$LOG_FILE"
            SERVICE_FOUND=true
        fi
    done
    if ! $SERVICE_FOUND; then
        echo "점검 대상 서비스 없음" >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
fi

# 로그인 실패 로그 (Ubuntu + RHEL 계열 모두 대응)
FAILED_LOGINS=$( (grep "Failed password" /var/log/auth.log 2>/dev/null; grep "Failed password" /var/log/secure 2>/dev/null) | tail -n 5 )

if $SUMMARY_MODE; then
    COUNT=$(echo "$FAILED_LOGINS" | grep -c .)
    if [ "$COUNT" -eq 0 ]; then
        echo "로그인 실패 기록: 없음"
    else
        echo "로그인 실패 기록: $COUNT건"
    fi
else
    echo "[보안 로그: 로그인 실패]" >> "$LOG_FILE"
    if [ -z "$FAILED_LOGINS" ]; then
        echo "최근 로그인 실패 기록 없음" >> "$LOG_FILE"
    else
        echo "$FAILED_LOGINS" >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
fi

# 시스템 에러 로그 (journalctl 없을 시 /var/log/messages)
if command -v journalctl &> /dev/null && pidof systemd &>/dev/null; then
    ERROR_LOGS=$(journalctl -p err -n 5)
else
    ERROR_LOGS=$(grep -i "error" /var/log/messages 2>/dev/null | tail -n 5)
fi

if $SUMMARY_MODE; then
    ERR_COUNT=$(echo "$ERROR_LOGS" | grep -c -v '^--')
    echo "시스템 에러 로그: $ERR_COUNT건 감지됨"
else
    echo "[최근 시스템 에러 로그]" >> "$LOG_FILE"
    echo "$ERROR_LOGS" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "===== 점검 완료 =====" >> "$LOG_FILE"
fi
