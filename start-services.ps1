# start-services.ps1
# Jalankan backend + Cloudflare tunnel untuk Trash Bounty

$BackendDir = "/mnt/c/Users/ASUS/Code/temporary_assignment/backend"
$TunnelConfig = "~/.cloudflared/config.yml"
$TunnelName = "go-api"
$DefaultBackendPort = "8080"
$BackendPort = if ($env:BACKEND_PORT) { $env:BACKEND_PORT } else { $DefaultBackendPort }
$BackendHealthUrl = "http://localhost:$BackendPort/v1/health"

function Test-BackendHealthy {
    return (wsl -e bash -c "curl -fsS --connect-timeout 1 --max-time 2 $BackendHealthUrl >/dev/null 2>&1 && echo yes || echo no").Trim() -eq "yes"
}

function Test-BackendPortInUse {
    $windowsListener = Get-NetTCPConnection -LocalPort ([int]$BackendPort) -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $windowsListener) {
        return $true
    }

    return (wsl -e bash -c "ss -ltn 'sport = :$BackendPort' | awk 'NR > 1 { found = 1 } END { exit found ? 0 : 1 }' >/dev/null 2>&1 && echo yes || echo no").Trim() -eq "yes"
}

Write-Host "=== Trash Bounty Service Starter ===" -ForegroundColor Cyan
Write-Host "[INFO] Backend port default repo = $DefaultBackendPort" -ForegroundColor DarkCyan
Write-Host "[INFO] Resolved backend port = $BackendPort" -ForegroundColor DarkCyan
if ($BackendPort -eq "8081") {
    Write-Host "[INFO] BACKEND_PORT=8081 aktif sebagai override tunnel-only lokal." -ForegroundColor Yellow
}

if (-not (Test-BackendHealthy) -and (Test-BackendPortInUse)) {
    Write-Host "[FAIL] Port $BackendPort sudah dipakai proses lain dan tidak merespons sebagai backend Trash Bounty." -ForegroundColor Red
    Write-Host "       Hentikan proses tersebut atau set BACKEND_PORT secara eksplisit. Script tidak akan pindah port otomatis." -ForegroundColor Red
    exit 1
}

# --- Cek apakah backend sudah berjalan ---
$backendRunning = wsl -e bash -c "pgrep -x server_linux > /dev/null 2>&1 && echo yes || echo no"
if ($backendRunning.Trim() -eq "yes") {
    Write-Host "[SKIP] Backend sudah berjalan." -ForegroundColor Yellow
} else {
    Write-Host "[START] Memulai backend..." -ForegroundColor Green
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "wsl -e bash -c 'cd $BackendDir && env PORT=$BackendPort ./server_linux'"
    ) -WindowStyle Normal
    Start-Sleep -Seconds 3
    if (Test-BackendHealthy) {
        Write-Host "[OK] Backend berjalan di localhost:$BackendPort" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Backend mungkin belum siap, cek terminal baru." -ForegroundColor Yellow
    }
}

# --- Cek apakah cloudflared sudah berjalan ---
$tunnelRunning = wsl -e bash -c "pgrep -af '[c]loudflared.*tunnel.*run.*$TunnelName' > /dev/null 2>&1 && echo yes || echo no"
if ($tunnelRunning.Trim() -eq "yes") {
    Write-Host "[SKIP] Cloudflare tunnel $TunnelName sudah berjalan." -ForegroundColor Yellow
} else {
    Write-Host "[START] Memulai Cloudflare tunnel ($TunnelName)..." -ForegroundColor Green
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-Command",
        "wsl -e bash -c 'cloudflared tunnel --config $TunnelConfig run $TunnelName'"
    ) -WindowStyle Normal
    Start-Sleep -Seconds 15
}

# --- Verifikasi end-to-end ---
Write-Host ""
Write-Host "[TEST] Verifikasi API via tunnel..." -ForegroundColor Cyan
$result = wsl -e bash -c "curl -s -o /dev/null -w '%{http_code}' https://trashbounty.kiryuken.my.id/v1/auth/login -X POST -H 'Content-Type: application/json' -d '{\"email\":\"test@test.com\",\"password\":\"test\"}' 2>&1"
$status = $result.Trim()

if ($status -eq "400" -or $status -eq "401" -or $status -eq "200") {
    Write-Host "[OK] API https://trashbounty.kiryuken.my.id/v1 aktif! (HTTP $status)" -ForegroundColor Green
} elseif ($status -eq "502" -or $status -eq "503") {
    Write-Host "[WARN] Tunnel jalan tapi backend belum siap. (HTTP $status)" -ForegroundColor Yellow
} else {
    Write-Host "[FAIL] API tidak merespons dengan benar. (HTTP $status)" -ForegroundColor Red
    Write-Host "       Pastikan backend dan tunnel sudah berjalan." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Selesai ===" -ForegroundColor Cyan
Write-Host "Backend : localhost:$BackendPort"
Write-Host "API URL : https://trashbounty.kiryuken.my.id/v1"
Write-Host "APK     : frontend\build\app\outputs\flutter-apk\app-release.apk"
