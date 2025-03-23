# 서버 자동 점검 시스템 기획서

## 프로젝트 개요
1. 프로젝트 주제  
 본 프로젝트는 서버 점검 및 장애 감지를 자동화하고, SSH 및 SFTP를 이용하여 로그를 중앙에서 수집하며, HTML 리포트를 생성하는 시스템을 개발하는 것이다.   
  이를 통해 서버 운영자가 일일이 서버에 접속하여 상태를 점검하는 부담을 줄이고, 장애 발생 시 신속하게 대응할 수 있도록 돕는 것이 목표이다.
2. 해결하려는 문제
    - 반복적인 수작업 문제
    - 기존에는 각 서버에 SSH로 접속하여 CPU, 메모리, 디스크 사용량 등을 직접 확인해야 함.
    - 중요한 서비스(웹 서버, 데이터베이스 등)의 상태를 사람이 직접 체크해야 함.
    - 시스템 로그를 직접 분석해야 하므로 침입 탐지 및 장애 감지가 어려움.
    - 서버 장애 발생 시 신속한 대응 어려움
    - 장애 발생 시 원인을 파악하기 위해 로그를 개별적으로 분석해야 하며, 시간이 오래 걸림.
    - 서버별 로그를 중앙에서 쉽게 관리할 방법이 없음.
3. 프로젝트 목표
    - 서버 점검 자동화: 각 서버에서 Bash, PowerShell 스크립트를 사용해 상태 점검 및 로그 분석 수행
    - 로그 중앙 수집: Python을 사용하여 SFTP로 모든 서버의 생성된 점검 로그를 수집
    - HTML 리포트 생성: 서버 점검 결과를 보기 쉽게 HTML로 시각화하여 분석 가능하도록 출력

---

## 활용 기술 및 개발 환경
1. 개발 언어 및 도구
    - Bash, PowerShell 스크립트 → 서버 점검 자동화 (CPU, 메모리, 디스크, 서비스 상태, 보안 로그 분석)
    - Python → SSH 및 SFTP를 이용한 서버 로그 수집, HTML 리포트 생성
    - HTML/CSS → 서버 점검 리포트 UI 구성
2. 개발 환경
    - 콘솔 운영 체제: Windows 계열
    - 서버 운영 체제: Linux 계열(CentOS, Ubuntu, Rocky Linux), Windows 계열(서버)
    - 제약 사항: 서버 간 직접 통신 불가 (네트워크 연결 제한), 기본 언어만 사용 가능

---

## 개발 계획(4주 개발 일정)
|주차|일자|개발 내용|
|--|----|--------|
|1주차|3.20. ~ 3.26.|프로젝트 설계 및 기본 환경 설정 (서버 점검 스크립트 초안 작성)|
|2주차|3.27. ~ 4.2.|서버 별 스크립트 완성 (서버 상태 점검 및 로그 분석 기능 추가)|
|3주차|4.2. ~ 4.9|Python을 이용한 SFTP 로그 수집 구현, HTML 리포트 템플릿 제작|
|4주차|4.10. ~ 4.16.|통합 테스트 및 최종 리포트 기능 개선, 문서 작성 및 발표 준비|
    

---

## 주요 기능
1. 서버 점검 자동화 (Bash, PowerShell)
    - 서버의 CPU, 메모리, 디스크 사용량 확인
    - 필수 서비스 (Apache, MySQL, SSH 등) 상태 점검
    - 보안 로그 분석 (침입 시도, 로그인 실패 감지)
    - 시스템 에러 로그 분석 (최근 10개 주요 오류 표시)
    - 결과를 저장(*.log 파일)*
    - *점검을 자동으로 실행하도록 크론(스케줄러) 등록*
2.  *SFTP를 이용한 로그 중앙 수집 (Python)*
    - *모든 서버의 점검 결과 (*.log 파일)를 자동으로 수집
    - 최신 로그를 중앙에서 확인할 수 있도록 SFTP로 다운로드
3. HTML 리포트 자동 생성 (Python)
    - 서버 점검 데이터를 HTML로 변환하여 한눈에 확인 가능
    - 서비스 상태, 로그인 실패 내역, 시스템 오류 등을 색상 및 테이블로 시각화
    - 관리자가 웹 브라우저에서 쉽게 확인 가능
    - HTML 리포트 예시
    
    ![image.png](attachment:b2eb86a9-a286-4c9b-b5e6-c37cc4a85a13:image.png)
            

---

## 예상되는 어려움 및 해결 방안
1. 서버 점검 데이터의 다양성(OS, 서비스마다 차이)
    - Linux(CentOS, Rocky)와 Windows Server의 점검 방식이 다름 → OS별로 맞춤형 Bash(PowerShell) 스크립트 작성하여 대응
2. 로그 파일 크기 증가 문제
    - 일정 기간이 지나면 오래된 로그를 자동 삭제하도록 스크립트에 정리 기능 추가
    - (예시) Linux: find /var/log/server_check/ -type f -mtime +30 -exec rm -f {} \;
    - (예시) Windows: `Get-ChildItem C:\Logs\ServerCheck\
3. 가독성 좋은 HTML 리포트 제작
    - 기본 테이블 기반의 HTML 리포트에서 Chart.js를 활용한 시각화 추가 (막대 그래프, 원형 그래프 등)
    - 중요한 정보를 강조 표시
    - HTML 리포트를 관리자가 웹 브라우저에서 쉽게 확인 가능하도록 디자인 개선

---

## 기대 효과
1. 서버 관리 업무 자동화
    - 반복적인 서버 점검 업무를 자동화하여 관리자의 부담을 줄임
    - 서버마다 수동으로 접속하여 상태를 확인하는 대신, 자동으로 점검 & 보고서 생성
2. 장애 및 보안 위협 조기 감지
    - CPU, 메모리, 디스크 사용량 증가를 자동으로 감지하여 장애 발생 전 대비 가능
    - 서비스 비정상 종료 및 보안 로그 분석을 통해 해킹 시도나 비정상적 접근을 조기에 탐지
3. 빠르고 직관적인 서버 상태 분석
    - HTML 리포트 제공 → 웹 브라우저에서 한눈에 서버 상태 확인 가능
    - Chart.js 그래프 활용 → CPU, 메모리, 디스크 사용량을 시각화하여 가독성 향상
    - 서비스 장애 및 로그인 실패 표시 → 오류 상황을 색상으로 강조하여 신속한 대응 가능