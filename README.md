# Codyssey B1-1. 시스템 관제 자동화 스크립트 개발

## 1. 미션 개요
이번 미션은 리눅스 서버 운영 환경에서 필요한 기본 보안 설정, 사용자 권한 관리, 애플리케이션 실행 환경 구성, 시스템 관제 자동화를 직접 수행하는 것을 목표로 한다.

서버 장애가 발생했을 때 로그와 관제 데이터가 없으면 원인을 정확히 분석하기 어렵고, 동일한 장애가 반복될 가능성이 높다. 따라서 본 미션에서는 SSH 포트 변경, Root 원격 접속 차단, 방화벽 정책 설정을 통해 기본적인 네트워크 보안을 구성하고, 역할 기반 계정과 그룹을 생성하여 협업 환경에서 최소 권한 원칙을 적용한다.

또한 제공된 Python 애플리케이션이 안정적으로 실행될 수 있도록 환경 변수, 디렉토리 구조, 키 파일, 로그 경로를 설정한다. 이후 Bash 기반의 `monitor.sh` 스크립트를 작성하여 애플리케이션 프로세스, 포트 상태, CPU, 메모리, 디스크 사용률을 점검하고, 그 결과를 로그 파일에 누적 기록한다.

마지막으로 `cron`을 이용해 모니터링 스크립트를 매분 자동 실행하도록 등록함으로써, 단순한 리눅스 명령어 사용을 넘어 실제 서버 운영에 필요한 보안, 권한, 관제, 로그 관리 흐름을 경험한다.

---

## 2. 최종 결과물
| # | 결과물 | 비고 |
|---|---|---|
| 1 | [요구사항 수행 내역서](docs/REPORT.md) | 문제별 수행 명령어 및 결과 정리 |
| 2 | [시스템 관제 자동화 스크립트](scripts/monitor.sh) | Bash 기반 모니터링 스크립트 |
| 3 | [트러블슈팅 문서](docs/TROUBLESHOOTING.md) | 문제 발생 원인 및 해결 과정 정리 |

---

## 3. 기능 요구 사항
### 3.1 SSH 설정
- SSH 접속 포트를 20022로 변경
- Root 원격 로그인을 차단
- 확인 방법: sshd 설정 파일에서 Port/PermitRootLogin 확인 / `ss -tulnp`

### 3.2 방화벽 설정 (택1)
- UFW 또는 firewalld 중 하나를 선택해 활성화
- 인바운드 허용 포트는 TCP 20022(SSH), TCP 15034(APP)만 허용한다.
- 확인 방법: 
  - UFW 선택 시: `ufw status`
  - firewalld 선택 시: `firewall-cmd --list-all`
  
### 3.3 계정/그룹 생성
**생성 계정**
| 계정 | 소속 그룹 | 역할 |
|---|---|---|
| `agent-admin` | `agent-common`, `agent-core` | 운영/관리, cron 실행자 |
| `agent-dev` | `agent-common`, `agent-core` | 개발/운영, monitor.sh 작성자 |
| `agent-test` | `agent-common` | QA/테스트 |

**생성 그룹**
| 그룹 | 소속 계정 |
|---|---|
| `agent-common` | `agent-admin`, `agent-dev`, `agent-test` |
| `agent-core` | `agent-admin`, `agent-dev` |

### 3.4 디렉토리 구조 및 접근 권한
**디렉토리 구조(AGENT_HOME 기준)**
- $AGENT_HOME
- $AGENT_HOME/upload_files
- $AGENT_HOME/api_keys
- /var/log/agent-app
  
**접근 권한(핵심 정책)**
| 디렉토리 | 접근 그룹 | 접근 권한 |
|---|---|---|
| `upload_files` | ONLY `agent-common` | R/W 가능 |
| `api_keys`, `/var/log/agent-app` | `agent-core` | R/W 가능 |

**확인 방법**
- `id` 사용
- `ls -l`/`getfacl`로 소요/권한 확인

### 3.5 애플리케이션 실행 환경 구성
**환경 변수**
| 변수 | 값 |
|---|---|
| `AGENT_HOME` | /home/agent-admin/agent-app |
| `AGENT_PORT` | 15034 |
| `AGENT_UPLOAD_PATH` | $AGENT_HOE/upload_files |
| `AGENT_KEY_PATH` | $AGENT_HOME/api_keys/t_secret.key |
| `AGENT_LOG_DIR` | /var/log/agent-app |

**키 파일 생성**
- 경로: $AGENT_HOME/api_keys/t_secret.key
- 내용: agent_api_key_test (1줄)

**앱 실행 및 성공 기준**
- 일반 계정으로 실행(루트 실행 금지)
- Boot Sequence 5단계가 모두 [OK]로 출력되고, 마지막에 “Agent READY”가 출력
- 앱이 0.0.0.0:15034로 LISTEN 상태
- 종료는 `Ctrl+C`
  
### 3.6 시스템 관제 자동화 스크립트(monitor.sh) 구현
**파일 위치/권한 정책**
- 경로: $AGENT_HOME/bin/monitor.sh
- 소유자: agent-dev
- 그룹: agent-core
- 권한: 750 (rwxr-x---)
- cron 실행 계정: agent-admin (agent-admin은 agent-core에 포함되어 실행 가능해야 함)

**동작**
1. Health Check(실패 시 종료)
   - 프로세스: `agent_app.py` 실행 상태를 확인하고, 비정상 시 `exit 1`
   - 포트: `TCP 15034` LISTEN 상태 확인, 비정상 시 `exit 1`
2. 상태 점검(경고만 출력)
   - 방화벽(UFW 또는 firewalld) 활성화 상태를 점검한다.
   - 비활성 상태면 [WARNING]을 출력하되, 스크립트는 종료하지 않는다.
3. 자원 수집
   - CPU 사용률(%)
   - 메모리 사용률(%)
   - 디스크 사용률(Root partition, Used %)
4. 임계값 경고(경고만 출력)
   - CPU > 20%: [WARNING]
   - MEM > 10%: [WARNING]
   - DISK_USED > 80%: [WARNING]
5. 로그 기록
   - 로그 파일: /var/log/agent-app/monitor.log
   - 로그 포맷: [YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
6. 로그 파일 용량 관리
   - monitor.log가 커지면 최대 10MB/10개 파일 유지(방법 자유: logrotate 사용 또는 스크립트 로직 구현)

### 3.7 자동 실행(cron) 설정
- agent-admin 계정의 crontab으로 monitor.sh를 매분 실행되도록 등록
- 등록 후 1~2분 내 monitor.log에 새 라인이 자동으로 누적되는 것을 확인
  
---

## 4. 제약 사항
- 자동화 스크립트는 Bash로만 작성한다(Python 등으로 대체 금지)
- 필요한 경우에만 sudo 사용(가능한 일반 계정으로 진행)
- 제공된 Python 앱은 “실행 대상”이며, 과제의 핵심은 관제/자동화 스크립트 구현이다.

---

## 5. 개발 환경
- macOS 환경에서 OrbStack을 이용해 Ubuntu Linux Machine을 생성하여 수행
- 실습 머신은 Ubuntu noble 기반의 amd64 아키텍처 환경
- 과제 요구사항인 "Ubuntu 22.04 LTS 또는 동등 리눅스 환경"에 해당하는 리눅스 서버 실습 환경으로 사용

| 항목 | 내용 |
|---|---|
| Host OS | macOS |
| Virtualization Tool | OrbStack |
| Linux Distro | Ubuntu |
| Version | noble |
| Architecture | amd64 |
| Machine Name | ubuntu |
| Domain | ubuntu.orb.local |
| IP Address | 192.168.139.16 |
| Username | yejoo031053822 |