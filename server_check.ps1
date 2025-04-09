# Windows용 서버 점검 스크립트 (형식 통일 버전)
chcp 65001 > $null
$OutputEncoding = [System.Text.UTF8Encoding]::new()

$now = Get-Date -Format "yyyy-MM-dd_HHmmss"
$logDir = "C:\Logs\ServerCheck"
$logFile = "$logDir\$now.txt"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Log {
    param([string]$text)
    Add-Content -Path $logFile -Value $text
}

Log "[리포트 생성 시각]"
Log "시각: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Log ""

# [서버 기본 정보]
$os = Get-CimInstance Win32_OperatingSystem
$uptime = ((Get-Date) - $os.LastBootUpTime).ToString("dd\.hh\:mm\:ss")
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' } | Select-Object -First 1).IPAddress

Log "[서버 기본 정보]"
Log "호스트명: $env:COMPUTERNAME"
Log "OS: $($os.Caption)"
Log "커널 버전: $($os.Version)"
Log "업타임: $uptime"
Log "IP 주소: $ip"
Log ""

# [CPU]
$cpu = Get-Counter '\Processor(_Total)\% Processor Time' | Select-Object -ExpandProperty CounterSamples
$cpuUsage = [math]::Round($cpu.CookedValue, 1)
Log "[CPU]"
Log "사용률: $cpuUsage %"
Log ""

# [메모리]
$totalMem = [math]::Round($os.TotalVisibleMemorySize / 1024, 1)
$freeMem = [math]::Round($os.FreePhysicalMemory / 1024, 1)
$usedMem = $totalMem - $freeMem
$memPercent = [math]::Round(($usedMem / $totalMem) * 100, 1)
Log "[메모리]"
Log "총 메모리: ${totalMem} MB"
Log "사용 중: ${usedMem} MB"
Log "사용률: $memPercent %"
Log ""

# [디스크 - 루트(/)]
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$totalDisk = [math]::Round($disk.Size / 1GB, 1)
$freeDisk = [math]::Round($disk.FreeSpace / 1GB, 1)
$usedDisk = $totalDisk - $freeDisk
$diskPercent = [math]::Round(($usedDisk / $totalDisk) * 100, 1)
Log "[디스크 - 루트(/)]"
Log "총 용량: ${totalDisk} GB"
Log "사용 중: ${usedDisk} GB"
Log "사용률: $diskPercent %"
Log ""

# [서비스 상태]
$services = @("w3svc", "WinRM", "TermService", "MSSQLSERVER")
Log "[서비스 상태]"
foreach ($svc in $services) {
    $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($svcObj) {
        Log "{$svc}: $($svcObj.Status)"
    } else {
        Log "{$svc}: 미설치 또는 찾을 수 없음"
    }
}
Log ""

# [자동 시작 서비스 중 중지된 항목]
Log "[자동 시작 서비스 중 중지된 항목]"
$autoStopped = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }
if ($autoStopped.Count -eq 0) {
    Log "모든 자동 시작 서비스가 실행 중입니다."
} else {
    foreach ($svc in $autoStopped) {
        Log "$($svc.Name): 중지됨"
    }
}
Log ""

# [디스크 용량 경고]
Log "[디스크 용량 경고]"
if ($diskPercent -ge 90) {
    Log "루트(/) 디스크 사용률 경고: ${diskPercent} %"
} else {
    Log "루트(/) 디스크 용량 정상: ${diskPercent} %"
}
Log ""

# [로그인 실패]
Log "[로그인 실패]"
foreach ($entry in $failLogons) {
    $time = $entry.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
    $msg = $entry.Message -replace '\\r|\\n', ' '  # 줄바꿈 제거
    Log \"$time - 로그인 실패 이벤트 감지: $msg\"
}
if ($failLogons.Count -eq 0 -or $null -eq $failLogons) {
    Log "최근 로그인 실패 기록 없음"
} else {
    foreach ($entry in $failLogons) {
        $time = $entry.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
        Log "$time - 로그인 실패 이벤트 감지"
    }
}
Log ""

# [시스템 에러 로그]
Log "[시스템 에러 로그]"
$errors = Get-WinEvent -LogName System -ErrorAction SilentlyContinue | Where-Object { $_.LevelDisplayName -eq "Error" } | Select-Object -First 5
if ($errors -and $errors.Count -gt 0) {
    foreach ($err in $errors) {
        $time = $err.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
        $msg = $err.Message -split "`n" | Select-Object -First 1
        Log "$time - $($err.ProviderName): $msg"
    }
} else {
    Log "최근 시스템 에러 없음"
}
Log ""

# [점검 상태]
Log "[점검 상태]"
Log "점검 완료"
