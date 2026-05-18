# 트러블 슈팅

## 1. agent-app 실행 실패

### 문제 상황 

Ubuntu 22.04 LTS 환경에서 제공된 `agent-app` 실행 파일에 실행 권한을 부여한 뒤 실행했으나, Python shared library 로드 실패 오류가 발생하였다.

### 실행 환경

| 항목 | 내용 |
|---|---|
| OS | Ubuntu 22.04 LTS (Jammy) |
| Architecture | x86_64 |
| 실행 파일 | agent-app |
| 실행 계정 | agent-admin |

### 문제 로그

```
agent-admin@ubuntu:~$ $AGENT_HOME/agent-app [PYI-552:ERROR] Failed to load Python shared library '/tmp/_MEId1kwEh/libpython3.12.so.1.0': /lib/x86_64-linux-gnu/libm.so.6: version GLIBC_2.38' not found (required by /tmp/_MEId1kwEh/libpython3.12.so.1.0) agent-admin@ubuntu:~$ 
```

### 원인 분석

오류 메시지의 핵심은 다음 부분이다.

```
version `GLIBC_2.38' not found
```

제공된 agent-app 실행 파일은 내부적으로 Python 3.12 관련 공유 라이브러리를 사용하며, 실행 과정에서 GLIBC_2.38 이상 버전을 필요로 한다.

하지만 기존에 사용하던 Ubuntu 22.04 LTS 환경에서는 그보다 하위 버전인 GLIBC 2.35 버전을 사용하여서, 실행 파일이 필요한 공유 라이브러리를 정상적으로 로드하지 못했다.

즉, 문제의 원인은 실행 권한 문제가 아니라 운영체제 기본 라이브러리 버전과 제공된 바이너리 실행 파일의 요구 라이브러리 버전이 맞지 않은 것이었다.

### 해결 방법

기존 Ubuntu 22.04 LTS 가상머신 대신, 더 최신 버전의 GLIBC를 제공하는 Ubuntu 24.04 환경으로 가상머신을 재구성하였다.

**변경 전 환경**

| 항목 | 내용 |
|---|---|
| OS | Ubuntu 22.04 LTS (Jammy) |
| Architecture | x86_64 |
| 결과 | GLIBC_2.38 not found 오류 발생 |

**변경 후 환경**

| 항목 | 내용 |
|---|---|
| OS | Ubuntu 24.04 (Noble Numbat) |
| Architecture | x86_64 |
| 결과 | agent-app 정상 실행 |

### 해결 결과

Ubuntu 24.04 x86_64 환경에서 동일한 agent-app 파일을 실행한 결과, GLIBC 버전 오류 없이 정상 실행되는 것을 확인하였다.

제공된 agent-app 파일은 x86_64(Intel/AMD) 아키텍처용 바이너리였으며, Ubuntu 24.04 x86_64 환경에서는 필요한 라이브러리 조건을 만족하여 정상적으로 동작하였다.

### 정리

이번 문제는 실행 파일 권한 문제가 아니라, 실행 환경의 시스템 라이브러리 버전 차이로 인해 발생한 문제였다.

따라서 바이너리 실행 파일이 정상 동작하지 않을 때는 다음 항목을 함께 확인해야 한다.

- 실행 권한이 있는지 확인
- OS 버전 확인
- CPU 아키텍처 확인
- 실행 파일이 요구하는 라이브러리 버전 확인
- 제공된 실행 파일과 현재 실행 환경이 호환되는지 확인
  
### 배운 점

리눅스에서 바이너리 실행 파일은 CPU 아키텍처뿐만 아니라 시스템 라이브러리 버전에도 영향을 받는다.

따라서 x86_64 아키텍처가 동일하더라도, Ubuntu 버전이나 GLIBC 버전이 맞지 않으면 실행에 실패할 수 있다.

이번 문제를 통해 실행 파일 오류를 확인할 때 단순히 권한만 확인하는 것이 아니라, OS 버전과 라이브러리 호환성까지 함께 확인해야 한다는 점을 알게 되었다.

