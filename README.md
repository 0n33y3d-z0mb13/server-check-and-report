# server-check-and-report

서버(Linux/Windows)의 상태를 자동 점검하고, 시각적으로 보기 쉬운 HTML 리포트를 생성하는 자동화 도구.

---

## 프로젝트 목적

- 리눅스 및 윈도우 서버의 주요 시스템 정보를 수집하여 로그 생성
- 최신 로그를 불러와 HTML 리포트 자동 생성

---

## 파일 구성 요소

| 파일명 | 설명 |
| --- | --- |
| `server_check.sh` | 리눅스 서버 상태 점검 스크립트 |
| `server_check.ps1` | 윈도우 서버 상태 점검 스크립트 (PowerShell) |
| `fetch_report.py` | 서버에서 점검 결과 파일 수집 (SSH, SCP ) |
| `generate_report_html.py` | 수집된 로그를 기반으로 HTML 리포트 생성 |
| `servers_config.py` | 수집 대상 서버 목록 구성 파일 |
| `run.py` | 전체 자동 실행 스크립트 (`fetch` → `generate`) |
| `/reports` | 불러온 로그 및 생성된 HTML 리포트 저장 |

---

## 지원 OS 및 특이사항

1. **각 배포판 및 버전을 최대한 지원할 수 있도록 하였음**
    - Ubuntu 14.04 / 16.04
    - CentOS 6.x / 7.x
    - Rocky 8+ / Fedora
    - Kali / Debian
    
    | 항목 | Ubuntu | CentOS/Fedora/Rocky |
    | --- | --- | --- |
    | 로그인 실패 로그 | `/var/log/auth.log` | `/var/log/secure` |
    | `journalctl` 사용 | O (systemd 기반) | O (다 사용 가능) |
    | Apache 서비스명 | `apache2` | `httpd` |
    | MySQL 서비스명 | `mysql` or `mariadb` | 보통 `mariadb` |
    | `hostname -I` 명령어 | 기본 설치됨 | 일부 배포판은 없음 |
    | OS 이름 추출 방식 | `/etc/os-release` | 동일함 |
2. **단독망에서의 사용을 고려하여 기본 라이브러리만 사용하도록 하였음**
    - yaml을 사용할 수 없어 서버 목록을 딕셔너리로 선언(`servers_config.py`)
    - paramiko를 사용할 수 없어 sftp 사용 불가 → ssh/scp로 대체

---

## 점검 항목

- OS 정보, 호스트명, IP 주소
- CPU/메모리/디스크 사용률
- 서비스 상태 및 자동 시작 서비스 확인
- 로그인 실패 내역
- 시스템 에러 로그

---

## 경고 기준

- **CPU 또는 메모리 사용률 ≥ 90%**
- **디스크 사용률 ≥ 80%**
- 조건을 초과하면 ⚠️ 경고 표시

---

## 사용 방법

### 1. 서버에 점검 스크립트 배포

- 리눅스: `server_check.sh` 실행 예약
    1. 실행 권한 부여
        
        ```bash
        chmod +x ~/server_check.sh
        ```
        
    2. 크론 설정 열기
        
        ```bash
        crontab -e
        ```
        
    3. 아래 한 줄 추가 (매일 06:00 실행)
        
        ```
        0 6 * * * /bin/bash /home/사용자명/server_check.sh
        ```
        
- 윈도우: `server_check.ps1` 예약 작업(Task Scheduler)
    - 작업 스케줄러에 등록하는 방법:
        1. **시작 메뉴 → 작업 스케줄러(Task Scheduler)** 실행
        2. **작업 만들기** 클릭
        3. **이름**: `서버 리포트 자동 생성`
        4. **트리거** 탭 → *매일 / 특정 시간* 설정
        5. **동작** 탭 → *프로그램 시작* 선택
            
            
            | 항목 | 값 예시 | 설명 |
            | --- | --- | --- |
            | 프로그램 | `C:\Users\me\AppData\Local\Programs\Python\Python311\python.exe` | `python` |
            | 인수 | `run.py` |  |
            | 시작 위치 | `C:\Users\me\Documents\server-check-and-report` | `run.py`가 있는 폴더 경로 |

### 2. 자동화를 위한 SSH 키 인증 설정

### SSH 키 인증 설정 방법

**1. [윈도우] 키 생성 (1회만 하면 됨)**

PowerShell에서:

```powershell
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_check_rsa
```

- `Enter passphrase`: 비워도 되고 입력해도 됨
- 결과:
    - 개인키: `C:\Users\<이름>\.ssh\id_check_rsa`
    - 공개키: `C:\Users\<이름>\.ssh\id_check_rsa.pub`

---

**2. [리눅스(칼리/우분투)] 공개키 등록**

**A. 공개키 붙여넣기**

```bash
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
# → Windows에서 만든 id_check_rsa.pub 내용 붙여넣기

```

---

**3. [리눅스] 퍼미션 설정**

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R $USER:$USER ~/.ssh
chmod 755 ~  # 홈 디렉토리 권한 너무 제한되면 인증 실패함
```

---

**4. [리눅스] SSH 서버 설정 확인 - 필수 항목 확인/수정**

```bash
sudo vim /etc/ssh/sshd_config

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

변경 후 재시작:

```bash
sudo systemctl restart ssh
```

---

**5. [윈도우] SSH 설정 - 파일 위치:** `C:\Users\<이름>\.ssh\config`

```
Host ubuntu-server
    HostName 123.123.123.123
    User ubuntu
    IdentityFile ~/.ssh/id_check_rsa

Host kali-server
    HostName 123.123.123.123
    User kali
    IdentityFile ~/.ssh/id_check_rsa

Host win-server
    HostName 123.123.123.123
    User user
    IdentityFile C:/Users/user/.ssh/id_check_rsa
```

- ~ 대신 절대경로(C:/Users/...) 쓰는 게 Windows에서는 더 안정적

---

**6. [윈도우에서] 비밀번호 없이 접속 확인**

```powershell
ssh kali-server
ssh ubuntu-server
ssh win-local
```

→ 모두 **비밀번호 없이 바로 로그인** 되면 설정 완료.

### 3. 로컬에서 수집 및 리포트 생성

```bash
python run.py
```

### 3. 결과 확인

- `reports/summary_YYYYMMDD_HHMMSS.html` 열기
- 요약 테이블 + 서버별 상세 로그 확인 가능
