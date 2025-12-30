# Master Destroy Script for TechNova Solutions
# Cleans up Azure Resources + Entra ID Identities

$ErrorActionPreference = "Stop"
$resourceGroupName = "TechNova-RG"

# --- HELPER FUNKCIJE ---
function Get-TechNovaConfig {
    $configPath = Join-Path $env:USERPROFILE ".technova_config"
    if (Test-Path $configPath) { return (Get-Content $configPath -Raw).Trim() }
    return $null
}

Write-Host ">>> POČETAK DESTRUKCIJE OKRUŽENJA <<<" -ForegroundColor Red

# 0. KORAK: PAMETNA PRIJAVA (Smart Login)
Write-Host "`n[0/2] Provjera Prijave..." -ForegroundColor Cyan

$storedTenantId = Get-TechNovaConfig
$targetTenantId = if (-not [string]::IsNullOrWhiteSpace($storedTenantId)) { $storedTenantId } else { $null }

# Azure CLI Login Check
if (Get-Command "az" -ErrorAction SilentlyContinue) {
    $azAccountShow = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $azAccountShow -or ($targetTenantId -and $azAccountShow.tenantId -ne $targetTenantId)) {
        Write-Host "Prijavljujem se na Azure CLI..." -ForegroundColor Yellow
        try {
            if ($targetTenantId) { az login --tenant $targetTenantId --output none } else { az login --output none }
        } catch {
            if ($targetTenantId) { az login --tenant $targetTenantId --use-device-code --output none } else { az login --use-device-code --output none }
        }
    } else {
        Write-Host "Već ste prijavljeni na Azure CLI." -ForegroundColor Green
    }
}

# Microsoft Graph Login Check
$mgContext = Get-MgContext
if (-not $mgContext -or ($targetTenantId -and $mgContext.TenantId -ne $targetTenantId)) {
    Write-Host "Prijavljujem se na Microsoft Graph..." -ForegroundColor Yellow
    $scopes = @("User.ReadWrite.All", "Group.ReadWrite.All")
    try {
        if ($targetTenantId) { Connect-MgGraph -TenantId $targetTenantId -Scopes $scopes -NoWelcome -ErrorAction Stop }
        else { Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop }
    } catch {
        if ($targetTenantId) { Connect-MgGraph -TenantId $targetTenantId -Scopes $scopes -UseDeviceAuthentication -NoWelcome }
        else { Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -NoWelcome }
    }
} else {
    Write-Host "Već ste prijavljeni na Microsoft Graph." -ForegroundColor Green
}

# 1. KORAK: Brisanje Resursa (Azure)
Write-Host "`n[1/2] Brisanje Azure Resursa ($resourceGroupName)..." -ForegroundColor Cyan

$rgExists = az group exists --name $resourceGroupName 2>$null
if ($rgExists -eq "true") {
    Write-Host "Brisanje Resource Grupe '$resourceGroupName' (ovo može potrajati)..." -ForegroundColor Magenta
    # Koristimo --no-wait=false (default je wait) jer želimo biti sigurni da je gotovo prije nego kažemo da je gotovo
    az group delete --name $resourceGroupName --yes --output none
    Write-Host "Resource Grupa uspješno obrisana." -ForegroundColor Green
} else {
    Write-Host "Resource Grupa ne postoji. Preskačem." -ForegroundColor DarkGray
}

# 2. KORAK: Brisanje Identiteta (Entra ID)
Write-Host "`n[2/2] Čišćenje Identiteta (Entra ID)..." -ForegroundColor Cyan
try {
    # Dot-Sourcing skripte za čišćenje
    . ./scripts/cleanup_identities.ps1
    Write-Host "Identiteti (korisnici i grupe) su uklonjeni." -ForegroundColor Green
} catch {
    Write-Error "Greška pri brisanju identiteta: $($_.Exception.Message)"
}

Write-Host "`n>>> OKOLINA JE POTPUNO UKLONJENA <<<" -ForegroundColor Green