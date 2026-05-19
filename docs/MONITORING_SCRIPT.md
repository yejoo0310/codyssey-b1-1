# 모니터링 스크립트 설명

## 1. 문서 목적
이 문서는 `scripts/monitor.sh`의 작성 목적, 실행 방식, 점검 항목, 로그 기록 방식, 자동 실행 설정을 설명한다.

`monitor.sh`는 제공 애플리케이션의 실행 상태와 서버 리소스 상태를 주기적으로 점검하고, 그 결과를 `/var/log/agent-app/monitor.log`에 누적 기록하기 위한 Bash 기반 시스템 관제 스크립트이다.

---

## 2. 스크립트 개요

| 항목 | 내용 |
|---|---|
| 스크립트 파일 | `scripts/monitor.sh` |
| 서버 배치 경로 | `$AGENT_HOME/bin/monitor.sh` |
| 실행 계정 | `agent-admin` |
| 작성/관리 계정 | `agent-dev` |
| 소유자 | `agent-dev` |
| 그룹 | `agent-core` |
| 권한 | `750` (`rwxr-x---`) |
| 로그 파일 | `/var/log/agent-app/monitor.log` |

서버 내 실제 배치 경로는 다음과 같다.

```bash
/home/agent-admin/agent-app/bin/monitor.sh
```

---

## 3. 권한 정책
`monitor.sh`는 다음 권한 정책을 따른다.

```
소유자: agent-dev
그룹: agent-core
권한: 750
```

권한 구조는 다음과 같다.
```
yejoo031053822@ubuntu:~$ sudo ls -l /home/agent-admin/agent-app/bin/monitor.sh
-rwxr-x--- 1 agent-dev agent-core 3960 May 19 13:50 /home/agent-admin/agent-app/bin/monitor.sh
yejoo031053822@ubuntu:~$
```

| 대상 | 권한 |	의미 |
|---|---|---|
| `agent-dev` |  rwx | 스크립트 작성, 수정, 실행 가능 |
| `agent-core` | r-x | 스크립트 읽기, 실행 가능 |
| 기타 사용자 | --- | 접근 불가 |

`agent-admin`은 `agent-core` 그룹에 포함되어 있으므로 `monitor.sh`를 실행할 수 있다.
반면 `agent-test`는 `agent-core` 그룹에 포함되지 않으므로 해당 스크립트에 접근할 수 없다.

권한 설정 명령어는 다음과 같다.

```
yejoo031053822@ubuntu:~$ sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
yejoo031053822@ubuntu:~$ sudo chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
```

---

## 4. Health Check 항목
1. `agent-app` 프로세스가 실행 중인지 확인
2. TCP 15034 포트가 LISTEN 상태인지 확인

### 전체 흐름
`main()`에서 Health Check는 다음 순서로 실행된다.
```
pid="$(find_app_pid)"
check_process "${pid}"
check_port
```
- find_app_pid: agent-admin 계정으로 실행 중인 agent-app 프로세스 PID를 찾는다.
- check_process "${pid}": PID가 비어 있으면 앱이 실행 중이 아니므로 [FAIL] 출력 후 exit 1
- check_port: 15034 포트가 LISTEN 상태인지 확인하고 아니면 [FAIL] 출력 후 exit 1

### 관련 상수
```
readonly APP_PROCESS_NAME="agent-app"
readonly APP_PROCESS_PATH="/home/agent-admin/agent-app/agent-app"
readonly APP_PORT="15034"
```
- `readonly`는 이 변수를 스크립트 실행 중에 바꿀 수 없게 하는 선언이다.
- `APP_PROCESS_NAME`: 출력 메시지에서 사용할 애플리케이션 이름
- `APP_PROCESS_PATH`: 실제 실행 파일의 전체 경로로 이 경로를 이용해서 `agent-admin` 계정이 실행한 정확한 경로의 프로세스만 찾을 수 있다.
- `APP_PORT`: 애플리케이션이 LISTEN해야 하는 포트 번호. `check_port()`에서 사용한다.

### `find_app_pid()`
이 함수는 실행 중인 앱 프로세스의 PID(Process ID, 프로세스 번호)를 찾는 함수이다.
```
find_app_pid() {
    pgrep -u agent-admin -fx "${APP_PROCESS_PATH}" | head -n 1
}
```
- `pgrep`: 실행 중인 프로세스 목록에서 조건에 맞는 프로세스를 찾아 PID만 출력하는 명령어 (`ps`(Process State로 현재 실행 중인 프로세스 상태를 출력하는 명령어)와 `grep`(파일이나 명령어 출력 결과에서 원하는 패턴을 찾는 명령어) 명령어를 묶음)
- `-u agent-admin`: 특정 사용자가 실행한 프로세스만 찾는다는 뜻이다. 따라서 `agent-admin` 계정이 실행한 프로세스만 검색한다는 뜻이다.
- `-f`: 프로세스 이름만 보는 것이 아니라 전체 실행 명령줄 전체를 대상으로 검색한다는 뜻이다. 이게 없으면 보통 `pgrep`은 프로세스 이름만 본다.(ex. agent-app) 
- `-x`: 정확히 일치하는 것만 찾겠다는 뜻이다.
- `|`: 파이프로 왼쪽 명령어의 출력 결과를 오른쪽 명령어의 입력으로 넘긴다.
- `head -n 1`: 출력 결과 중 첫 번째 줄만 가져온다.

### `check_process()`
이 함수는 앱 프로세스가 실행 중인지 검사한다.
```
check_process() {
  local pid="$1"

  echo "[HEALTH CHECK]"

  if [[ -z "${pid}" ]]; then
    echo "Checking process '${APP_PROCESS_NAME}'... [FAIL]"
    exit 1
  fi

  echo "Checking process '${APP_PROCESS_NAME}'... [OK] (PID: ${pid})"
}
```
- `local pid="$1"`: 이 함수에 전달된 첫 번째 인자인 `$1`을 지역 변수 `pid`에 넣는다. 지역 변수를 이용하는 이유는 함수 밖의 변수와 충돌하지 않기 위해서이다.
- `if [[ -z "${pid}" ]]; then`: `pid` 변수가 비었는지 확인한다. `-z`는 문자열 길이가 0인지 검사하는 조건식으로 `pid` 변수가 비었으면 앱 프로세스를 찾지 못한 것이므로 실패 메시지를 출력한다.
- `exit 1`: 스크립트를 실패 상태로 종료한다. 
- `fi`: Bash에서 `if`문을 끝내는 키워드이다.

### `check_port()`
이 함수는 TCP 15034 포트가 LISTEN 상태인지 확인한다.
```
check_port() {
  if ss -ltnH | awk '{print $4}' | grep -Eq ":${APP_PORT}$"; then
    echo "Checking port ${APP_PORT}... [OK]"
    echo
    return
  fi

  echo "Checking port ${APP_PORT}... [FAIL]"
  exit 1
}
```
- `if ss -ltnH | awk '{print $4}' | grep -Eq ":${APP_PORT}$"; then`
  - `ss`는 socket statistics의 약자로 현재 시스템의 네트워크 소켓 상태를 보여주는 명령어이다. 포트가 열려 있는지 확인할 때 사용한다.
  - `-l`: LISTEN 상태인 포트만 보기
  - `-t`: TCP 소켓만 보기
  - `-u`: UDP 소켓만 보기
  - `-H`: 헤더 줄 숨기기
  - `awk '{print $4}'`: `awk`는 텍스트를 컬럼 단위로 처리하는 도구이다. 여기서 4번째 컬럼은 `Local Address:Port`이다. 이 명령어를 통해 LISTEN 상태인 프로세스의 IP 주소와 포트를 가져온다.
  - `grep`: 텍스트에서 특정 패턴을 찾는 명령어
  - `-E`: 확장 정규식 사용
  - `-q`: 검사만 하고 결과를 화면에 출력하지 않고 성공 실패 상태만 반환
  - `":${APP_PORT}$"`: `$`는 정규식에서 문자열 끝을 의미한다. 즉 :15034로 끝나는 줄만 찾는다.
- `return`: 함수를 종료하고 호출한 곳으로 되돌아간다.

#### 추가 자료
```
agent-admin@ubuntu:~$ ss -ltn
State   Recv-Q   Send-Q     Local Address:Port      Peer Address:Port  Process  
LISTEN  0        4096             0.0.0.0:20022          0.0.0.0:*              
LISTEN  0        4096                [::]:20022             [::]:*              
agent-admin@ubuntu:~$ 
```

---

## 5. 방화벽 점검
1. 방화벽이 활성화되어 있는지 점검

### 전체 흐름
`main()`에서 방화벽 점검은 다음 순서로 실행된다.
```
check_firewall
```
- UFW 또는 firewalld 활성화 여부를 확인한다. 비활성화여도 종료하지 않고 [WARNING]만 출력한다.
  
### `check_firewall()`
이 함수는 방화벽 활성화 상태를 점검한다. 다만 프로세스/포트 체크와 달리 방화벽이 비활성화되어 있어도 스크립트를 종료하지 않는다.

UFW가 있는지 확인하고, 있으면 활성화 상태인지 확인하고 결과를 출력한다.
UFW가 없으면 firewalld가 있는지 확인하고, 있으면 활성화 상태인지 확인하고 결과를 출력한다.
둘 다 없으면 방화벽 도구가 없다고 출력한다.
```
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
```
**(1) UFW 확인**
- `if command -v ufw >/dev/null 2>&1; then`
  - `command -v ufw`: `ufw` 명령어가 시스템에 존재하는지 확인 (ex. /usr/sbin/ufw)
  - `>/dev/null 2>&1`: 표준 출력과 에러 출력을 모두 버린다. 따라서 화면에는 아무것도 출력되지 않고 성공/실패 여부만 조건문에서 사용된다.
- `if ufw status 2>/dev/null | grep -q "Status: active";`
  - `ufw status`: UFW 상태를 보여준다. (ex. Status: active)
  - `grep -q "Status: active"`: 해당 문자열이 있는지 확인한다.
- `return`: UFW 방화벽이 활성 상태이므로 함수를 종료한다.
- `if grep -q "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null; then`: UFW 상태 확인의 보조 수단이다. `ufw status`의 경우 sudo 권한이 없으면 확인을 못할 수도 있기 때문에 실패할 경우 보조 수단에서 상태를 확인한다.
  - `/etc/ufw/ufw.conf` 파일에는 UFW 활성화 여부가 설정되어 있을 수 있다.
  - `ENABLED=yes`로 시작하는 줄이 있으면 UFW 활성화된 것으로 판단한다.
- UFW가 있지만 active가 아니면 경고를 출력한다.

**(2) firewalld 확인**
- `if firewall-cmd --state >/dev/null 2>&1; then`
  - `firewall-cmd`는 firewalld를 관리하는 명령어이다.
  - `firewall-cmd --state`가 정상적으로 실행되면 firewalld가 동작 중이라고 보고 함수를 종료한다.

---
## 6. 자원 수집
1. CPU 사용률(%) 출력
2. 메모리 사용률(%) 출력 
3. 디스크 사용률(Root partition, Used %) 출력

### 전체 흐름
`main()`에서 자원 수집은 다음 순서로 실행된다.
```
cpu_usage="$(collect_cpu_usage)"
mem_usage="$(collect_mem_usage)"
disk_usage="$(collect_disk_usage)"

print_resource_result "${cpu_usage}" "${mem_usage}" "${disk_usage}"
```
- cpu_usage: CPU 사용률을 계산한 함수의 출력값을 저장한다.
- mem_usage: 메모리 사용률을 계산한 함수의 출력값을 저장한다.
- disk_usage: 디스크 사용률을 계산한 함수의 출력값을 저장한다.
- print_resource_result()를 통해 CPU, 메모리, 디스크 사용률을 출력한다.

### `collect_cpu_usage()`
이 함수는 `top` 명령어 결과에서 CPU idle 값을 찾아서 CPU 사용률을 계산한다.
```
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
```
- `LA_ALL=C`
  - `LA_ALL`: 명령어 출력의 언어/지역 설정을 지정하는 환경 변수
  - `LA_ALL=C`: 출력 형식을 영어/표준 형식에 가깝게 고정하는 의미
  - `top` 출력은 시스템 언어 설정에 따라 달라질 수 있는데 출력 형식이 달라지면 `awk`가 원하는 값을 제대로 못 찾을 수도 있어서 사용한다.
- `top -bn1` 
  - `top`: 시스템의 전반적인 상태(CPU, 메모리 사용량 등)를 실시간으로 보여주는 명령어
  - `-b`: batch mode
  - `-n1`: `top`을 실행하면 화면이 계속 갱신되어서 `-n1`을 이용해서 한번만 출력하고 종료한다.
- `| awk '...'`
  - `awk`는 왼쪽의 명령어 출력 결과를 받아서 줄 단위, 필드 단위로 분석
  - `awk /^%?Cpu/`: 출력 중 CPU 정보를 담은 줄만 찾는다. (`^`: 줄의 시작, `%?`: %가 0개 또는 1개)
- `for (i = 1; i <= NF; i++)`
  - `awk`에서 현재 줄은 공복 기준으로 여러 필드로 나뉜다. `NF`는 현재 줄의 필드 개수를 의미한다.
- `if ($i ~ /^id,?$/)`
  - 현재 필드 `$i`가 id 또는 id,인지 확인한다. (`~`는 `awk`에서 정규식 매칭 연산자이다.)
- `idle = $(i - 1)`: `id` 필드 바로 앞 필드가 `idle` 비율 값이므로 i에서 1을 뺀다.
- `gsub(",", "", idle)`
  - `gsub`: 문자열에서 특정 문자를 모두 치환하는 `awk` 함수
  - `idle` 값에서 쉼표(,)를 뺀다.
- `exit`: `awk` 내부에서 처리를 끝내고 함수를 종료한다.


#### 추가자료
```
agent-admin@ubuntu:~$ top -bn1
top - 16:39:30 up  4:56,  3 users,  load average: 0.00, 0.00, 0.00
Tasks:  31 total,   1 running,  30 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st 
MiB Mem :  16049.5 total,  15716.2 free,    464.4 used,     66.5 buff/cache     
MiB Swap:  17073.4 total,  17073.4 free,      0.0 used.  15585.1 avail Mem 

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
      1 root      20   0   21444   4676   1520 S   0.0   0.0   0:00.27 systemd
     53 root      20   0 1246648   9632     44 S   0.0   0.1   0:00.34 orbstac+
    120 root      19  -1  206104   3892   2644 S   0.0   0.0   0:00.77 systemd+
    170 root      20   0   23984   1348     16 S   0.0   0.0   0:00.05 systemd+
    248 systemd+  20   0   19008   1760    592 S   0.0   0.0   0:00.04 systemd+
```

### `collect_mem_usage()`
이 함수는 `free` 명령어로 메모리 정보를 가져오고, 전체 메모리 대비 사용 중인 메모리 비율을 계산한다.
```
collect_mem_usage() {
  free | awk '/Mem:/ {
    printf "%.1f", ($3 / $2) * 100
  }'
}
```
- `free`: 시스템 메모리 사용량을 보여주는 명령어
- `free | awk '/Mem:/`: `free` 출력 결과에서 'Mem:' 문자열이 있는 줄에서만 중괄호 안 코드를 실행한다.
- `$2`: total 메모리 값
- `$3`: 사용한 메모리 값

#### 추가자료
```
agent-admin@ubuntu:~$ free
               total        used        free      shared  buff/cache   available
Mem:        16434644      478060    16100016        1072       49684    15956584
Swap:       17483212           0    17483212
agent-admin@ubuntu:~$
```
`free`에서 `$3` used는 리눅스 커널이 사용하는 버퍼/캐시 계산 방식에 따라 체감 사용량과 다를 수 있다. 실무에서는 보통 available 기준으로 계산하는 방식이 많다.
```
실제 메모리 압박률 = (total - available) / total * 100
```

### `collect_disk_usage()`
이 함수는 루트 파티션 `/`의 디스크 사용률을 가져온다. 
(루트 파티션은 `/` 디렉토리가 실제로 저장되어 있는 디스크 영역을 말한다. `/`가 꽉 차면 로그 기록, 앱 실행, 패키지 설치 등 서버 운영에 문제가 생길 수 있어 관제 대상이 된다.)
```
collect_disk_usage() {
  df -P / | awk 'NR==2 {
    gsub("%", "", $5)
    print $5
  }'
}
```
- `df -P /`
  - `df`는 disk free의 약자로, 파일시스템의 디스크 사용량을 보여주는 명령어
  - `-P`: POSIX 출력 형식으로 보여달라는 옵션이다. 이 옵션을 사용하는 이유는 출력 형식을 안정적으로 만들기 위해서이다. 스크립트에서 awk로 컬럼을 뽑을 때 출력 형식이 일정해야 안전하기 때문이다.
  - `/`: 루트 파티션
- `| awk 'NR==2`
  - `NR==2`: `NR`은 `awk`에서 현재 줄 번호이다. 첫번째 줄은 헤더이므로 두번째 줄을 사용한다.
  
#### 추가자료
```
agent-admin@ubuntu:~$ df -P /
Filesystem     1024-blocks     Used Available Capacity Mounted on
/dev/vdb1        432479040   876756 431602284       1% /
agent-admin@ubuntu:~$ 
```

### `print_resource_result()`
수집된 자원 사용률 값을 출력한다.
```
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
```

### 자원 수집 방식 요약
| 항목 | 사용 명령어 | 계산 방식 |
|---|---|---|
| CPU 사용률 | top -bn1 | 100 - idle |
| 메모리 사용률 | free | used / total * 100 |
| 디스크 사용률 | df -P / |	루트 파티션 $5 사용률에서 % 제거 |

---
## 7. 임계값 경고
1. CPU > 20%: [WARNING] 출력
2. MEM > 10%: [WARNING] 출력 
3. DISK_USED > 80%: [WARNING] 출력

### 전체 흐름
`main()`에서 임계값 경고는 다음 순서로 실행된다.
```
print_warnings "${cpu_usage}" "${mem_usage}" "${disk_usage}"
```
- `print_warnigs` 함수를 이용해서 임계값 경고를 출력한다.

### 관련 상수
```
readonly CPU_THRESHOLD="20"
readonly MEM_THRESHOLD="10"
readonly DISK_THRESHOLD="80"
```
- `CPU_THRESHOLD`: CPU 경고 기준값
- `MEM_THRESHOLD`: 메모리 경고 기준값
- `DISK_THRESHOLD`: 디스크 경고 기준값

### `print_warnings()`
이 함수는 수집된 CPU, 메모리, 디스크 사용률을 받아서 임계값을 넘었는지 검사하고, 넘었으면 [WARNING] 메시지를 출력한다.
```
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
```
- `local warning_printed="false"`: 경고가 하나라도 출력되었는지 기억하는 변수이다. 이 변수를 쓰는 이유는 경고가 하나라도 출력되면 마지막에 빈 줄을 하나 출력해서 콘솔을 보기 좋게 만들기 위해서이다.
- `if awk "BEGIN { exit !(${cpu_usage} > ${CPU_THRESHOLD}) }"; then`
  - Bash 자체도 숫자 비교를 할 수 있지만, Bash의 기본 산술 비교는 정수 중심이다. 그러나 수집한 자원 사용률은 소수점이 나올 수도 있다. Bash에서 이런 소수점 비교를 하기 어려워서 awk를 사용해 소수점 비교를 하였다.
  - `BEGIN`: 입력 파일이나 파이프가 없어도 바로 실행되는 블록이다. 다른 텍스트 없이 변수 값으로 계산하기 위해 사용한다.
  - `awk`에서 `exit 0`이면 성공, `exit 1` 실패이다. `cpu_usage`가 `CPU_THRESHOLD`보다 클 때 `then` 안으로 들어가게 하기 위해 `!`을 사용해서 조건이 참(1)이 될 때 0으로 바꾼다.

---
## 8. 로그 기록
1. 로그 파일: /var/log/agent-app/monitor.log
2. 로그 포맷: [YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%

### 전체 흐름
`main()`에서 로그 기록은 다음 순서로 실행된다.
```
append_log "${pid}" "${cpu_usage}" "${mem_usage}" "${disk_usage}"
print_log_appended
```
- 위에서 수집한 `pid`, `cpu_usage`, `mem_usage`, `disk_usage` 값을 사용해서 로그를 기록한다.
- 로그 기록 후 메시지를 출력한다.

### 관련 상수
```
readonly LOG_FILE="/var/log/agent-app/monitor.log"
```
- `LOG_FILE`: 로그를 기록할 파일 경로이다. 모든 로그 기록 함수가 같은 경로를 사용하게 만들기 위해서 상수로 정의하였다.

### `append_log()`
이 함수는 수집한 모니터링 결과를 로그 파일에 한 줄 추가하는 함수이다.
```
append_log() {
  local pid="$1"
  local cpu_usage="$2"
  local mem_usage="$3"
  local disk_usage="$4"
  local current_datetime

  current_datetime="$(date '+%Y-%m-%d %H:%M:%S')"

  echo "[${current_datetime}] PID:${pid} CPU:${cpu_usage}% MEM:${mem_usage}% DISK_USED:${disk_usage}%" >> "${LOG_FILE}"
}
```
- `current_datetime="$(date '+%Y-%m-%d %H:%M:%S')"`
  - `date`: 현재 날짜와 시간을 출력하는 명령어
  - `'+%Y-%m-%d %H:%M:%S'`: 원하는 형식

### `print_log_appended()`
```
print_log_appended() {
  echo "[INFO] Log appended: ${LOG_FILE}"
}
```

---
## 9. 로그 디렉토리 권한
로그 디렉토리는 `agent-core` 그룹만 읽기/쓰기 가능하도록 설정한다.
새로 생성되는 로그 파일도 agent-core 권한을 유지하도록 default ACL을 설정한다.
```
yejoo031053822@ubuntu:~$ sudo chown agent-admin:agent-core /var/log/agent-app
yejoo031053822@ubuntu:~$ sudo chmod 2770 /var/log/agent-app
yejoo031053822@ubuntu:~$ sudo setfacl -m d:g:agent-core:rwx /var/log/agent-app
yejoo031053822@ubuntu:~$ sudo setfacl -m d:m:rwx /var/log/agent-app
yejoo031053822@ubuntu:~$ 
```
권한 확인
```
yejoo031053822@ubuntu:~$ sudo ls -ld /var/log/agent-app
drwxrws---+ 1 agent-admin agent-core 0 May 18 16:39 /var/log/agent-app
yejoo031053822@ubuntu:~$ sudo getfacl /var/log/agent-app
getfacl: Removing leading '/' from absolute path names
# file: var/log/agent-app
# owner: agent-admin
# group: agent-core
# flags: -s-
user::rwx
group::rwx
other::---
default:user::rwx
default:group::rwx
default:group:agent-core:rwx
default:mask::rwx
default:other::---

yejoo031053822@ubuntu:~$ 
```

---
## 10. 수동 실행 방법
우선 `agent-admin` 계정에서 `agent-app`을 실행한다.
```
$AGENT_HOME/bin/
```
`monitor.sh`도`agent-admin` 계정으로 실행한다.
```
/home/agent-admin/agent-app/bin/monitor.sh
```

---
## 11. cron 자동 실행
`monitor.sh`는 `agent-admin` 계정의 crontab에 등록하여 매분 실행한다.
이를 통해 `monitor.sh`을 굳이 실행하지 않아도 `agent-app`만 실행되면 매분 `monitor.sh`가 실행되어 로그가 기록된다.

로그가 쌓이는 걸 실시간으로 확인할 수 있는 명령어
```
tail -f /var/log/agent-app/monitor.log
```