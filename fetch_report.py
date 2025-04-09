import subprocess
import os
from datetime import datetime
from servers_config import servers  # 서버 목록 정보 불러오기

# 리포트 저장 폴더 설정
REPORT_DIR = "reports"
os.makedirs(REPORT_DIR, exist_ok=True)  # 폴더 없으면 생성

def fetch_latest_report(server):
    # 원격 서버에서 가장 최근 로그 파일 1개 가져오기
    list_cmd = (
        f"ssh {server['host']} "
        f"\"bash -c 'ls -t {server['path']}/*{server['file_ext']}'\""
    )
    
    try:
        # 최신 파일 목록 받아오기 (시간순 정렬, 가장 위가 최신)
        result = subprocess.check_output(list_cmd, shell=True, text=True).splitlines()
        latest_remote_file = result[0] if result else None
    except subprocess.CalledProcessError:
        print(f"[-][{server['host']}] 목록 가져오기 실패")
        return None

    if not latest_remote_file:
        print(f"[-][{server['host']}] 로그 파일 없음")
        return None

    # 로컬 저장 경로 지정 (서버명_파일명 형식)
    local_file = os.path.join(REPORT_DIR, f"{server['host']}_{os.path.basename(latest_remote_file)}")

    # 파일 복사 (scp 사용)
    scp_cmd = f'scp "{server["host"]}:{latest_remote_file}" "{local_file}"'

    try:
        subprocess.run(scp_cmd, shell=True, check=True)
        print(f"[+][{server['host']}] 파일 저장됨 → {local_file}")
        return local_file
    except subprocess.CalledProcessError:
        print(f"[-][{server['host']}] 다운로드 실패")
        return None

def main():
    files = []

    # 서버 목록 순회하며 리포트 파일 가져오기
    for server in servers:
        f = fetch_latest_report(server)
        if f:
            files.append(f)

    # 결과 출력
    if files:
        print("[+] 파일 가져오기 성공.")
    else:
        print("[-] 가져온 파일이 없습니다.")

if __name__ == "__main__":
    main()
