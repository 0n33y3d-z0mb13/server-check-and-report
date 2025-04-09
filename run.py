import subprocess

print("[+] 서버 리포트 수집 시작...")
subprocess.run(["python", "fetch_report.py"], check=True)

print("[*] HTML 리포트 생성 중...")
subprocess.run(["python", "generate_report_html.py"], check=True)

print("[+] 작업 완료!")