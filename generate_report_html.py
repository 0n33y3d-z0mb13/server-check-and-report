import os
import re
from datetime import datetime

# 리포트 폴더 및 출력 파일 경로 설정
REPORT_DIR = "reports"
OUTPUT_FILE = os.path.join(REPORT_DIR, f"summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html")

# 경고 임계값 설정
CPU_THRESHOLD = 90
MEM_THRESHOLD = 90
DISK_THRESHOLD = 80

# 리포트 파일 리스트 불러오기 (.log / .txt)
def get_report_files():
    return sorted(
        [os.path.join(REPORT_DIR, f) for f in os.listdir(REPORT_DIR)
         if f.endswith(".log") or f.endswith(".txt")],
        key=lambda x: os.path.getmtime(x),
        reverse=True
    )

# 인코딩 자동 감지 후 파일 열기
def try_open_file(path):
    for enc in ("utf-8-sig", "utf-8", "euc-kr", "cp949"):
        try:
            with open(path, encoding=enc) as f:
                return f.read()
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError(f"[-] 인코딩 실패: {path}")

# HTML 이스케이프 처리
def html_escape(text):
    return (text.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace('"', "&quot;")
                .replace("'", "&#39;"))

# 리소스 사용량이 임계값 초과 시 경고 아이콘 붙이기
def add_usage_warning(value_str, threshold):
    try:
        value = float(value_str.replace('%', '').strip())
        if value >= threshold:
            return f"⚠️ {value_str}"
    except:
        pass
    return value_str

# 리포트 원문에서 요약 정보 추출 (정규표현식 사용)
def extract_summary(text):
    def match(pattern):
        m = re.search(pattern, text, re.IGNORECASE)
        return m.group(1).strip() if m else "N/A"

    cpu_raw = match(r"\[CPU\][^\[]*?사용률:\s*([\d\.]+ ?%)")
    mem_raw = match(r"\[메모리\][^\[]*?사용률:\s*([\d\.]+ ?%)")
    disk_raw = match(r"\[디스크.*?\][^\[]*?사용률:\s*([\d\.]+ ?%)")

    summary = {
        "host": match(r"호스트명:\s*(.+)"),
        "ip": match(r"IP\s*주소:\s*([\d\.]+)"),
        "os": match(r"OS:\s*(.+)"),
        "cpu": add_usage_warning(cpu_raw, CPU_THRESHOLD),
        "mem": add_usage_warning(mem_raw, MEM_THRESHOLD),
        "disk": add_usage_warning(disk_raw, DISK_THRESHOLD),
        "service_warn": "⚠️" if re.search(r"(중지됨|inactive|Stopped|미설치|찾을 수 없음)", text) else "✅",
        "login_warn": "⚠️" if re.search(r"(로그인 실패 기록: \d+건|Failed password)", text) else "✅",
        "error_warn": "⚠️" if re.search(r"\[시스템 에러 로그\](?![^\[]*없음)", text) else "✅"
    }
    return summary

# HTML 리포트 생성 메인 함수
def generate_html_report():
    files = get_report_files()
    if not files:
        print("[-] 리포트 디렉토리에 로그 파일이 없습니다.")
        return

    summaries = []

    # HTML 기본 헤더 및 스타일 설정
    html_parts = [
        "<!DOCTYPE html><html lang='ko'><head>",
        "<meta charset='UTF-8'>",
        "<title>서버 점검 리포트</title>",
        "<style>",
        "body { font-family: sans-serif; padding: 2em; background-color: #111; color: #eee; }",
        "table { border-collapse: collapse; margin-bottom: 2em; width: 100%; }",
        "th, td { border: 1px solid #444; padding: 8px 12px; text-align: center; }",
        "th { background: #222; }",
        "details { margin-bottom: 1.5em; }",
        "summary { cursor: pointer; font-weight: bold; color: #ccc; }",
        "pre { background: #222; padding: 1em; border: 1px solid #444; border-radius: 5px; overflow-x: auto; color: #ccc; }",
        ".warn { color: red; font-weight: bold; }",
        ".note { font-size: 0.9em; color: #aaa; }",
        "</style>",
        "</head><body>",
        f"<h1>📊 서버 점검 리포트</h1><p>생성 시각: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p><hr>"
    ]

    # 로그 파일마다 요약 정보 추출
    for path in files:
        content = try_open_file(path)
        summary = extract_summary(content)
        summaries.append((os.path.basename(path), summary, html_escape(content)))

    # 요약 테이블 헤더 작성
    html_parts.append("<h2>📌 서버 요약 테이블</h2>")
    html_parts.append(
        "<table><tr>"
        "<th>로그명</th><th>호스트명</th><th>IP</th><th>OS</th>"
        "<th>CPU</th><th>메모리</th><th>디스크</th>"
        "<th>서비스</th><th>로그인</th><th>에러</th></tr>"
    )

    # 요약 테이블 본문 작성
    for file, summary, _ in summaries:
        def warn_cell(val): return f"<span class='warn'>{val}</span>" if '⚠️' in val else val
        html_parts.append(
            f"<tr><td>{file}</td>"
            f"<td>{summary['host']}</td><td>{summary['ip']}</td><td>{summary['os']}</td>"
            f"<td>{warn_cell(summary['cpu'])}</td><td>{warn_cell(summary['mem'])}</td><td>{warn_cell(summary['disk'])}</td>"
            f"<td>{warn_cell(summary['service_warn'])}</td>"
            f"<td>{warn_cell(summary['login_warn'])}</td>"
            f"<td>{warn_cell(summary['error_warn'])}</td></tr>"
        )

    html_parts.append("</table>")
    html_parts.append(f"<p class='note'>⚠️ CPU 또는 메모리 사용률이 {CPU_THRESHOLD}% 이상, 디스크 사용률이 {DISK_THRESHOLD}% 이상인 경우 경고로 표시</p><br>")

    # 각 서버의 원문 로그 출력 (토글)
    for file, _, content in summaries:
        html_parts.append(f"<details><summary>{file}</summary><pre>{content}</pre></details>")

    html_parts.append("</body></html>")

    # HTML 파일 저장
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(html_parts))

    print(f"[+] HTML 리포트 생성 완료: {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_html_report()
