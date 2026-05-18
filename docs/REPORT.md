# 요구사항 수행 내역서

## 목차
- [0. OrbStack 환경 설정](#0-orbstack-환경-설정)
- [1. SSH 설정](#1-ssh-설정-포트-변경-및-root-원격-로그인-차단)

## 0. OrbStack 환경 설정
이번 실습에서는 컨테이너 대신 OrbStack을 이용해 Ubuntu Linux 가상머신을 띄워서 인프라 환경을 구축했다. 

Orbstack은 macOS에서 가상머신과 도커 컨테이너를 아주 빠르고 가볍게 돌릴 수 있게 도와주는 관리 도구이다. 
그 위에서 돌아가는 Ubuntu 가상머신은 맥 안에 가상으로 만든 별개의 독립된 컴퓨터라고 보면 된다.

가상머신은 실제 하드웨어 위에 하이퍼바이저라는 층을 두고, 그 위에 독자적인 커널과 OS를 통째로 올려서 완벽한 격리가 된다. 도커는 프로세스를 격리하는 것으로 호스트 커널을 빌려서 사용한다. 

가상머신은 호스트의 커널이 아닌, 자신이 설치한 Ubuntu의 커널을 직접 사용한다. 따라서 자신의 커널이 따로 있으니 마음대로 방화벽을 껐다 켰다 할 수 있고, SSH 포트 변경이나 시스템 로그 관리도 OS 전체를 통제하는 가상머신 환경에서라야 실제 서버처럼 동작한다.

도커는 별도의 커널을 가지지 않고 호스트의 기능을 빌려서 쓴다. 방화벽은 커널의 영역인데 도커는 그 커널을 직접 수정할 권한이 없기 때문에 방화벽 설정 변경 같은 일을 할 수 없다. (만약 도커에서 방화벽을 마음대로 바꿀 수 있다면 옆집 컨테이너의 보안까지 망가뜨릴 수 있기 때문)

### 환경 확인
```
**yejoo031053822@ubuntu**:**~**$ cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo
**yejoo031053822@ubuntu**:**~**$ uname -m
x86_64
**yejoo031053822@ubuntu**:**~**$ whoami
yejoo031053822
**yejoo031053822@ubuntu**:**~**$ hostname -I
192.168.139.16 fd07:b51a:cc66:0:e4f5:87ff:fe8f:a8bf
**yejoo031053822@ubuntu**:**~**$
```
![Ubuntu VM 설정 확인](./images/ubuntu_vm.png)

---

## 1. SSH 설정 (포트 변경 및 Root 원격 로그인 차단)
### 1.1 목적
**(1) SSH 포트를 변경하는 이유**

SSH는 네트워크를 통해 다른 컴퓨터에 안전하게 접속해서 명령어를 실행하는 기술로, 리눅스 서버에 원격 접속할 때 사용하는 대표적인 접속 방식이다.

기본 SSH 포트는 보통 22번입니다.

기본값: 22/tcp -> 변경값: 20022/tcp

공격자나 자동화된 봇은 인터넷에 있는 서버들을 대상으로 22번 포트를 계속 스캔한다.
그래서 SSH 포트를 기본값인 22에서 20022로 바꾸면, 무작위 자동 스캔이나 단순 공격 시도를 줄이는 데 도움이 된다.

다만 이건 공격 표면을 줄이는 보조적인 보안 설정으로 완전한 보안 대책은 되지 않는다.

**(2) Root 원격 로그인을 차단하는 이유**

`root`는 리눅스에서 모든 권한을 가진 관리자 계정이다.

만약 외부에서 바로 root 계정으로 SSH 접속이 가능하면, 공격자는 다음처럼 시도할 수 있다.

```
ssh root@서버IP
```

이 경우 공격자가 맞춰야 하는 정보는 사실상 비밀번호 하나뿐이다.

반대로 Root 원격 로그인을 막으면, 서버 관리자는 일반 계정으로 먼저 접속하고 필요한 작업만 sudo로 실행한다.

```
ssh 일반사용자@서버IP -p 20022
sudo 명령어
```

즉, Root 원격 로그인을 차단한 이유는 관리자 계정에 대한 직접 공격을 방지하고, 각 사용자가 개인 계정으로 접속한 뒤 필요한 경우에만 sudo를 사용하도록 하기 위함이다. 

이를 통해 SSH 접속 기록(`sudo journalctl -u ssh`)과 sudo 실행 로그(`sudo journalctl | grep sudo`)를 사용자 계정 기준으로 추적할 수 있으며, 모든 작업을 root 권한으로 수행하는 것보다 실수로 시스템 전체에 영향을 주는 위험을 줄일 수 있다. 이는 사용자와 프로세스에 필요한 최소한의 권한만 부여하는 최소 권한 원칙에 부합한다.


### 1.2 사전 설정

### 1.3 sshd 설정 변경

SSH 서버의 설정값들이 들어있는 파일에서 설정 변경
```
sudo vim /etc/ssh/sshd_config
```

20022로 포트 변경
```
#Port 22 -> Port 20022
```

Root 접속 차단
```
#PermitRootLogin prohibit-password -> PermitRootLogin no
```

변경 사항 적용: 설정 적용을 위해 ssh 서비스를 재시작 해야한다.
```
sudo systemctl restart ssh
```

### 1.4 수행 내역
**SSH 포트 변경 확인 내역**
- **확인 방법**: `ss-tulnp` 명령어를 통한 포트 리슨 상태 점검
- **증거 지표**
  - 기본 22번 포트가 아닌 문제 요구사항에 지정된 포트 **20022**가 활성화됨
  - 상태가 **LISTEN**으로 표시되어 외부 접속 수신이 가능함을 확인
- **결과 데이터**
  ```text
  yejoo031053822@ubuntu-agent:~$ sudo ss -tulnp | grep sshd
  tcp   LISTEN 0      4096               0.0.0.0:22        0.0.0.0:*    users:(("sshd",pid=4061,fd=3),("systemd",pid=1,fd=51))
  tcp   LISTEN 0      4096                  [::]:22           [::]:*    users:(("sshd",pid=4061,fd=4),("systemd",pid=1,fd=55))
  yejoo031053822@ubuntu-agent:~$ 
  ```

**Root 원격 접속 차단 설정 내역**
- **확인 방법**: `grep PermitRootLogin /etc/ssh/sshd_config` 명령어를 통해 SSH 설정 파일을 열어 PermitRootLogin 항목을 확인
- **결과 데이터**
  ```text
  yejoo031053822@ubuntu-agent:~$ grep PermitRootLogin /etc/ssh/sshd_config
  PermitRootLogin no
  # the setting of "PermitRootLogin prohibit-password".
  yejoo031053822@ubuntu-agent:~$ 
  ```

---
## 2. 방화벽 활성화 및 20022/tcp, 15034/tcp만 허용
#### (1) 방화벽 설정
기본 정책 설정: 모든 들어오는 신호는 일단 막고, 나가는 신호는 허용하는 기본 정책 설정
```
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

과제에서 요구한 필수 포트 허용
```
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp
```

방화벽 활성화: 설정한 규칙을 시스템에 실제로 적용한다.
```
sudo ufw enable
```

#### (2) 수행 내역
**방화벽 설정 확인**
- **확인 방법**: `sudo ufw status verbose` 명령어를 통해 방화벽 상태를 확인
- **결과 데이터**
  ```text
  yejoo031053822@ubuntu-agent:~$ sudo ufw status verbose
  Status: active
  Logging: on (low)
  Default: deny (incoming), allow (outgoing), deny (routed)
  New profiles: skip

  To                         Action      From
  --                         ------      ----
  20022/tcp                  ALLOW IN    Anywhere                  
  15034/tcp                  ALLOW IN    Anywhere                  
  20022/tcp (v6)             ALLOW IN    Anywhere (v6)             
  15034/tcp (v6)             ALLOW IN    Anywhere (v6)             

  yejoo031053822@ubuntu-agent:~$       
  ```
---
### 3. 계정/그룹 생성 및 디렉토리 구조 설정 및 권한 설정
#### (1) 계정/그룹 생성 및 권한 설정

**그룹 생성**
```
sudo groupadd agent-common
sudo groupadd agent-core
```

**사용자 생성 및 그룹 배정**
```
sudo useradd -m -G agent-common,agent-core agent-admin
sudo useradd -m -G agent-common,agent-core agent-dev
sudo useradd -m -G agent-common agent-test
```

**디렉토리 구조 생성**
```
sudo mkdir -p /home/agent-admin/agent-app/upload_files
sudo mkdir -p /home/agent-admin/agent-app/api_keys
sudo mkdir -p /var/log/agent-app
```

**접근 권한**
- `upload_files`
```
sudo chown agent-admin:agent-admin /home/agent-admin/agent-app/upload_files
sudo chmod 770 /home/agent-admin/agent-app/upload_files
sudo setfacl -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
```
- `api_keys`
```
sudo chown agent-admin:agent-admin /home/agent-admin/agent-app/api_keys
sudo chmod 700 /home/agent-admin/agent-app/api_keys
sudo setfacl -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys
```
- `/var/log/agent-app`
```
sudo chown root:agent-core /var/log/agent-app
sudo chmod 770 /var/log/agent-app
```
#### (2) 수행 내역
**사용자 생성 및 그룹 배정**
- **확인 방법**: `id` 명령어를 통해 사용자 생성 및 소속 그룹을 확인 / `
- **결과 데이터**
  ```text
  yejoo031053822@ubuntu-agent:~$ id agent-admin
  uid=1000(agent-admin) gid=1002(agent-admin) groups=1002(agent-admin),1000(agent-common),1001(agent-core)
  yejoo031053822@ubuntu-agent:~$ id agent-dev
  uid=1001(agent-dev) gid=1003(agent-dev) groups=1003(agent-dev),1000(agent-common),1001(agent-core)
  yejoo031053822@ubuntu-agent:~$ id agent-test
  uid=1002(agent-test) gid=1004(agent-test) groups=1004(agent-test),1000(agent-common)
  yejoo031053822@ubuntu-agent:~$ 
  ```
 
**디렉토리 구조**
- **확인 방법**: `tree` 명령어를 이용해 특정 디렉토리 하위 구조를 트리 형태로 출력해서 확인
- **결과 데이터**
  ```text
  yejoo031053822@ubuntu-agent:~$ sudo tree /home/agent-admin/agent-app
  /home/agent-admin/agent-app
  ├── api_keys
  └── upload_files

  3 directories, 0 files
  ```
  ```text
  yejoo031053822@ubuntu-agent:~$ tree /var/log/agent-app
  /var/log/agent-app

  0 directories, 0 files
  ```

**권한 설정**
- **확인 방법**: `getfacl` 명령어를 이용해 소유/권한 확인
- **결과 데이터**
  ```text
  yejoo031053822@ubuntu-agent:~$ sudo getfacl /home/agent-admin/agent-app/upload_files
  getfacl: Removing leading '/' from absolute path names
  # file: home/agent-admin/agent-app/upload_files
  # owner: agent-admin
  # group: agent-admin
  user::rwx
  group::r-x
  group:agent-common:rwx
  mask::rwx
  other::---

  yejoo031053822@ubuntu-agent:~$ sudo getfacl /home/agent-admin/agent-app/api_keys
  getfacl: Removing leading '/' from absolute path names
  # file: home/agent-admin/agent-app/api_keys
  # owner: agent-admin
  # group: agent-admin
  user::rwx
  group::---
  group:agent-core:rwx
  mask::rwx
  other::---

  yejoo031053822@ubuntu-agent:~$ ls -ld /var/log/agent-app
  drwxrwx--- 1 root agent-core 0 May 14 15:48 /var/log/agent-app
  yejoo031053822@ubuntu-agent:~$ 
  ```

---
### 4. 애플리케이션 실행 환경 구성 
#### (1) 애플리케이션 실행 환경 구성
**환경 변수 설정**
agent-admin 계정의 설정 파일(./bashrc)에 환경 변수를 기록
```
agent-admin@ubuntu-agent:~$ cat <<EOF >> ~/.bashrc
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=\$AGENT_HOME/upload_files
export AGENT_KEY_PATH=\$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
EOF
agent-admin@ubuntu-agent:~$ 
```
수정한 설정을 현재 터미널 세션에 즉시 적용
```
agent-admin@ubuntu-agent:~$ source ~/.bashrc
```

**키 파일 생성**
```
agent-admin@ubuntu-agent:~$ echo "agent_api_key_test" > $AGENT_KEY_PATH
agent-admin@ubuntu-agent:~$ chmod 600 $AGENT_KEY_PATH
```
(보안을 위해 키 파일 자체의 권한을 본인만 읽을 수 있게 설정함)

**agent-app 파일을 우분투 서버로 옮기기**
```
yejoo031053822@c4r8s8 ~ % scp -P 20022 ~/Downloads/agent-app agent-admin@192.168.139.51:/home/agent-admin/agent-app/
agent-admin@192.168.139.51's password: 
agent-app                                     100% 7741KB  51.4MB/s   00:00    
yejoo031053822@c4r8s8 ~ % 
```

**agent-app 실행**
```
agent-admin@ubuntu-agent:~$ ls -l /home/agent-admin/agent-app
total 7744
-rw-r--r--  1 agent-admin agent-admin 7926296 May 14 18:28 agent-app
drwxrwx---+ 1 agent-admin agent-admin      24 May 14 18:23 api_keys
drwxrwx---+ 1 agent-admin agent-admin       0 May 14 15:48 upload_files
agent-admin@ubuntu-agent:~$ chmod +x $AGENT_HOME/agent-app
agent-admin@ubuntu-agent:~$ $AGENT_HOME/agent-app
```

#### (2) 수행 내역
**환경 변수 설정 확인**
  ```
  agent-admin@ubuntu-agent:~$ env | grep AGENT
  AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
  AGENT_PORT=15034
  AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys/t_secret.key
  AGENT_HOME=/home/agent-admin/agent-app
  AGENT_LOG_DIR=/var/log/agent-app
  agent-admin@ubuntu-agent:~$ 
  ```

**키 파일 생성 확인**
  ```
  agent-admin@ubuntu-agent:~$ cat $AGENT_HOME/api_keys/t_secret.key
  agent_api_key_test
  agent-admin@ubuntu-agent:~$ 
  ```

**앱 실행 및 Boot Sequence 5단계 성공 확인**
  ```
  agent-admin@ubuntu-agent:~$ $AGENT_HOME/agent-app
  >>> Starting Agent Boot Sequence...
  [1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1000)
  [2/5] Verifying Environment Variables     [OK]
   ... All required Envs correct
  [3/5] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
  [4/5] Checking Port Availability          [OK]
   ... Port 15034 is available.
  [5/5] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
  ------------------------------------------------------------
  All Boot Checks Passed!
  Agent READY
  2026-05-14 18:36:23,468 [INFO] [SafetyGuard] Process priority lowered (nice=10).
  ```

**앱 LISTEN 상태 확인**
  ```
  agent-admin@ubuntu-agent:~$ netstat -an | grep 15034
  tcp        0      0 0.0.0.0:15034           0.0.0.0:*               LISTEN     
  agent-admin@ubuntu-agent:~$ 
  ```

---
### 5. 시스템 관제 자동화 스크립트(monitor.sh) 구현
monitor.sh 실행 결과
```
agent-admin@ubuntu-agent:~$ /home/agent-admin/agent-app/bin/monitor.sh
ERROR: You need to be root to run this script
[WARNING] Firewall is inactive or unreachable.
====== SYSTEM MONITOR RESULT ======
Checking process 'agent-app'... [OK] (PID: 5083)
Checking port 15034... [OK]

[RESOURCE MONITORING]
CPU Usage : 0%
MEM Usage : 3.75324%
DISK Used : 1%

[INFO] Log appended: /var/log/agent-app/monitor.log
agent-admin@ubuntu-agent:~$ 
```

/var/log/agent-app/monitor.log 누적 기록 확인(최근 라인)
```
agent-admin@ubuntu-agent:~$ tail -n 5 /var/log/agent-app/monitor.log
[2026-05-14 19:55:35] PID:5083 CPU:0% MEM:5.05729% DISK_USED:1%
[2026-05-14 19:56:45] PID:5083 CPU:0% MEM:4.32365% DISK_USED:1%
agent-admin@ubuntu-agent:~$ 
```  
---
### 6. crontab 매분 실행 및 자동 실행 확인
매분 실행 설정
```
agent-admin@ubuntu-agent:~$ crontab -l
# Edit this file to introduce tasks to be run by cron.
# 
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
# 
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use '*' in these fields (for 'any').
# 
# Notice that tasks will be started based on the cron's system
# daemon's notion of time and timezones.
# 
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
# 
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
# 
# For more information see the manual pages of crontab(5) and cron(8)
# 
# m h  dom mon dow   command
* * * * * /home/agent-admin/agent-app/bin/monitor.sh
agent-admin@ubuntu-agent:~$ 
```

실시간 로그 확인
```
agent-admin@ubuntu-agent:~$ tail -f /var/log/agent-app/monitor.log
[2026-05-14 19:55:35] PID:5083 CPU:0% MEM:5.05729% DISK_USED:1%
[2026-05-14 19:56:45] PID:5083 CPU:0% MEM:4.32365% DISK_USED:1%
[2026-05-14 20:03:21] PID:5083 CPU:0% MEM:3.75324% DISK_USED:1%
[2026-05-14 20:13:01] PID:5083 CPU:0% MEM:3.81879% DISK_USED:1%
```

## 2. 필수 증거 자료 체크리스트
- [x] SSH 포트 변경(20022) 및 Root 원격 접속 차단 설정 확인 내역
- [x] 방화벽(UFW 또는 firewalld) 활성화 및 20022/tcp, 15034/tcp만 허용 내역
- [x] 계정/그룹(agent-admin/dev/test, agent-common/core) 생성 확인 내역
- [x] 디렉토리 구조 및 권한(ACL 포함) 확인 내역
- [x] 앱 Boot Sequence 5단계 [OK] 및 “Agent READY” 확인 내역
- [x] monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역
- [x] /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역
- [x] crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역

## 3. 실행 결과 (스크린샷)
### 포트 및 Root 원격 접속 차단 결과
![포트 및 Root 원격 접속 차단 설정](./images/Port_PermitRootLogin.png)

### 방확벽 설정
![방화벽 설정 상태 확인](./images/UFW.png)

### 사용자 생성 및 그룹 배정
![사용자 계정 및 그룹 확인](./images/useradd.png)

### 디렉토리 구조 확인
![디렉토리 구조](./images/directory.png)

### 권한 부여 확인
![파일 권한 부여 확인](./images/ACL.png)

### 환경 변수 설정 확인
![환경 변수 확인](./images/environment.png)

### api key 파일 생성 확인
![api key 파일 확인](./images/api_key.png)

### 애플리케이션 실행 Boot Sequence 확인 
![Boot Sequence 확인](./images/Boot%20Sequence.png)

### 앱 LISTEN 상태 확인
![앱 LISTEN 상태 확인](./images/Listen.png)

### monitor.sh 실행 결과
![monitor.sh 실행 결과](./images/script.png)

### monitor.log 내역
![monitor.log 내역](./images/log.png)

### crontab 설정 후 로그 확인
![로그 확인](./images/crontab.png)