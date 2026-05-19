#!/usr/bin/env bash

set -u

readonly APP_PROCESS_NAME="agent-app"
readonly APP_PROCESS_PATH="/home/agent-admin/agent-app/agent-app"
readonly APP_PORT="15034"
readonly LOG_FILE="/var/log/agent-app/monitor.log"
readonly STATISTICS_SAMPLE_LIMIT="10"

readonly CPU_THRESHOLD="20"
readonly MEM_THRESHOLD="10"
readonly DISK_THRESHOLD="80"

print_title() {
  echo "====== SYSTEM MONITOR RESULT ======"
  echo
}

find_app_pid() {
    pgrep -u agent-admin -fx "${APP_PROCESS_PATH}" | head -n 1
}

check_process() {
  local pid="$1"

  echo "[HEALTH CHECK]"

  if [[ -z "${pid}" ]]; then
    echo "Checking process '${APP_PROCESS_NAME}'... [FAIL]"
    exit 1
  fi

  echo "Checking process '${APP_PROCESS_NAME}'... [OK] (PID: ${pid})"
}

check_port() {
  if ss -ltnH | awk '{print $4}' | grep -Eq ":${APP_PORT}$"; then
    echo "Checking port ${APP_PORT}... [OK]"
    echo
    return
  fi

  echo "Checking port ${APP_PORT}... [FAIL]"
  exit 1
}

check_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
      return
    fi

    if grep -q "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null; then
      return
    fi

    echo "[WARNING] Firewall is inactive"
    echo
    return
  fi

  if command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state >/dev/null 2>&1; then
      return
    fi

    echo "[WARNING] Firewall is inactive"
    echo
    return
  fi

  echo "[WARNING] Firewall tool not found"
  echo
}

collect_cpu_usage() {
  LC_ALL=C top -bn1 | awk '
    /^%?Cpu/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^id,?$/) {
          idle = $(i - 1)
          gsub(",", "", idle)
          printf "%.1f", 100 - idle
          exit
        }
      }
    }
  '
}

collect_mem_usage() {
  free | awk '/Mem:/ {
    printf "%.1f", ($3 / $2) * 100
  }'
}

collect_disk_usage() {
  df -P / | awk 'NR==2 {
    gsub("%", "", $5)
    print $5
  }'
}

print_resource_result() {
  local cpu_usage="$1"
  local mem_usage="$2"
  local disk_usage="$3"

  echo "[RESOURCE MONITORING]"
  echo "CPU Usage : ${cpu_usage}%"
  echo "MEM Usage : ${mem_usage}%"
  echo "DISK Used  : ${disk_usage}%"
  echo
}

print_warnings() {
  local cpu_usage="$1"
  local mem_usage="$2"
  local disk_usage="$3"
  local warning_printed="false"

  if awk "BEGIN { exit !(${cpu_usage} > ${CPU_THRESHOLD}) }"; then
    echo "[WARNING] CPU threshold exceeded (${cpu_usage}% > ${CPU_THRESHOLD}%)"
    warning_printed="true"
  fi

  if awk "BEGIN { exit !(${mem_usage} > ${MEM_THRESHOLD}) }"; then
    echo "[WARNING] MEM threshold exceeded (${mem_usage}% > ${MEM_THRESHOLD}%)"
    warning_printed="true"
  fi

  if awk "BEGIN { exit !(${disk_usage} > ${DISK_THRESHOLD}) }"; then
    echo "[WARNING] DISK threshold exceeded (${disk_usage}% > ${DISK_THRESHOLD}%)"
    warning_printed="true"
  fi

  if [[ "${warning_printed}" == "true" ]]; then
    echo
  fi
}

append_log() {
  local pid="$1"
  local cpu_usage="$2"
  local mem_usage="$3"
  local disk_usage="$4"
  local current_datetime

  current_datetime="$(date '+%Y-%m-%d %H:%M:%S')"

  echo "[${current_datetime}] PID:${pid} CPU:${cpu_usage}% MEM:${mem_usage}% DISK_USED:${disk_usage}%" >> "${LOG_FILE}"
}

print_log_appended() {
  echo "[INFO] Log appended: ${LOG_FILE}"
}

main() {
  local pid
  local cpu_usage
  local mem_usage
  local disk_usage

  print_title

  pid="$(find_app_pid)"

  check_process "${pid}"
  check_port
  check_firewall

  cpu_usage="$(collect_cpu_usage)"
  mem_usage="$(collect_mem_usage)"
  disk_usage="$(collect_disk_usage)"

  print_resource_result "${cpu_usage}" "${mem_usage}" "${disk_usage}"
  print_warnings "${cpu_usage}" "${mem_usage}" "${disk_usage}"

  append_log "${pid}" "${cpu_usage}" "${mem_usage}" "${disk_usage}"
  print_statistics_report
  print_log_appended
}

main "$@"