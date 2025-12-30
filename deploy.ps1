# Master Deploy Script for TechNova Solutions
# Orchestrates Identity Creation (Entra ID) + Infrastructure Provisioning (Bicep)

$ErrorActionPreference = "Stop"

# --- HELPER FUNKCIJE ---

function Get-TechNovaConfig {
    $configPath = Join-Path $env:USERPROFILE ".technova_config"
    if (Test-Path $configPath) {
        return (Get-Content $configPath -Raw).Trim()
    }
    return $null
}

function Set-TechNovaConfig {
    param($TenantId)
    $configPath = Join-Path $env:USERPROFILE ".technova_config"
    $TenantId | Set-Content -Path $configPath -Force
}

# --- POČETAK ---

Write-Host ">>> POČETAK DEPLOYMENTA <<<" -ForegroundColor Green

# 0. KORAK: PAMETNA PRIJAVA (Smart Login)
Write-Host "`n[0/3] Provjera Prijave..." -ForegroundColor Cyan

# 0.1 Učitavanje spremljenog Tenanta (da ne pitamo svaki put)
$storedTenantId = Get-TechNovaConfig
$targetTenantId = $null

if (-not [string]::IsNullOrWhiteSpace($storedTenantId)) {
    Write-Host "Pronađen spremljeni Tenant ID: $storedTenantId" -ForegroundColor DarkGray
    $targetTenantId = $storedTenantId
} else {
    $targetTenantId = Read-Host "Unesite Tenant ID za prijavu (npr. kborbasalgebra.onmicrosoft.com)"
    if (-not [string]::IsNullOrWhiteSpace($targetTenantId)) {
        Set-TechNovaConfig -TenantId $targetTenantId
        Write-Host "Tenant ID spremljen za buduća pokretanja." -ForegroundColor Gray
    }
}

# 0.2 Provjera postojećih sesija
$azContext = Get-AzContext
$mgContext = Get-MgContext

# Logika za Azure PowerShell
if ($azContext -and ($azContext.Tenant.Id -eq $targetTenantId -or $azContext.Tenant.Directory -eq $targetTenantId)) {
    Write-Host "Već ste prijavljeni na Azure ($($azContext.Account))." -ForegroundColor Green
} else {
    Write-Host "Prijavljujem se na Azure..." -ForegroundColor Yellow
    if ($targetTenantId) { Connect-AzAccount -Tenant $targetTenantId -ErrorAction Stop }
    else { Connect-AzAccount -ErrorAction Stop }
}

# Logika za Azure CLI (az login)
if (Get-Command "az" -ErrorAction SilentlyContinue) {
    # Brza provjera jesmo li logirani
    $azAccountShow = az account show --output json 2>$null | ConvertFrom-Json
    
    if ($azAccountShow -and ($azAccountShow.tenantId -eq $targetTenantId)) {
        Write-Host "Već ste prijavljeni na Azure CLI." -ForegroundColor Green
    } else {
        Write-Host "Prijavljujem se na Azure CLI..." -ForegroundColor Yellow
        try {
            # Pokušaj interaktivno prvo
            if ($targetTenantId) { az login --tenant $targetTenantId --output none }
            else { az login --output none }
        } catch {
            Write-Host "Interaktivna prijava nije uspjela. Prebacujem na Device Code..." -ForegroundColor Yellow
            if ($targetTenantId) { az login --tenant $targetTenantId --use-device-code --output none }
            else { az login --use-device-code --output none }
        }
    }
}

# Logika za Microsoft Graph
$scopes = @("User.ReadWrite.All", "Group.ReadWrite.All", "Domain.Read.All", "Directory.Read.All", "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess", "Agreement.Read.All")
if ($mgContext -and ($mgContext.TenantId -eq $targetTenantId)) {
    Write-Host "Već ste prijavljeni na Microsoft Graph." -ForegroundColor Green
} else {
    Write-Host "Prijavljujem se na Microsoft Graph..." -ForegroundColor Yellow
    try {
        if ($targetTenantId) { Connect-MgGraph -TenantId $targetTenantId -Scopes $scopes -NoWelcome -ErrorAction Stop }
        else { Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop }
    } catch {
        Write-Host "Prebacujem na Device Code za Graph..." -ForegroundColor Yellow
        if ($targetTenantId) { Connect-MgGraph -TenantId $targetTenantId -Scopes $scopes -UseDeviceAuthentication -NoWelcome }
        else { Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -NoWelcome }
    }
}

# 0.3 Registracija Providera (Samo tiha provjera)
Write-Host "`n[INFO] Provjera Azure Resource Providera..." -ForegroundColor DarkGray
$providers = @("Microsoft.Network", "Microsoft.Compute", "Microsoft.Storage", "Microsoft.Insights")
foreach ($p in $providers) {
    if (Get-Command "az" -ErrorAction SilentlyContinue) {
        az provider register --namespace $p --wait --output none 2>$null
    } else {
        Register-AzResourceProvider -ProviderNamespace $p -ErrorAction SilentlyContinue | Out-Null
    }
}

# 1. KORAK: Identiteti (Dot-Sourcing)
Write-Host "`n[1/3] Konfiguracija Identiteta (Entra ID)..." -ForegroundColor Cyan
try {
    # Dot-Sourcing: Skripta se izvršava u trenutnom scope-u
    . ./scripts/deploy_identities.ps1
    
    # Provjera varijabli postavljenih u skripti
    if (-not $DevGroupId -or -not $SalesGroupId -or -not $SupportGroupId) {
        throw "Identiteti nisu ispravno postavljeni. Varijable su prazne."
    }

    Write-Host "Identiteti potvrđeni: Dev($DevGroupId), Sales($SalesGroupId), Support($SupportGroupId)" -ForegroundColor Green
} catch {
    Write-Error "Greška u koraku Identiteta: $($_.Exception.Message)"
    exit 1
}

# 1.1 KORAK: Propagacija Identiteta (s Progress Bar-om)
Write-Host "`n[INFO] Čekam replikaciju identiteta (120 sekundi)..." -ForegroundColor Yellow
for ($i = 1; $i -le 120; $i++) {
    Write-Progress -Activity "Čekanje replikacije Entra ID grupa..." -Status "$i / 120 sekundi" -PercentComplete (($i / 120) * 100)
    Start-Sleep -Seconds 1
}
Write-Progress -Activity "Čekanje replikacije Entra ID grupa..." -Completed

# 2. KORAK: Infrastruktura (Bicep)
Write-Host "`n[2/3] Deployment Azure Infrastrukture (Bicep)..." -ForegroundColor Cyan

$params = @{
    devGroupObjectId     = $DevGroupId
    salesGroupObjectId   = $SalesGroupId
    supportGroupObjectId = $SupportGroupId
    adminPassword        = "TechNova2025!" 
    location             = "francecentral"
}

# Pretvaranje hashtable-a u format za az deployment
$bicepParams = $params.Keys | ForEach-Object { "$_=$($params[$_])" }

$maxRetries = 3
$retryCount = 0
$deploymentSuccess = $false

do {
    try {
        $retryCount++
        if ($retryCount -gt 1) { Write-Host "Pokušaj deploymenta $retryCount od $maxRetries..." -ForegroundColor Cyan }

        if (Get-Command "az" -ErrorAction SilentlyContinue) {
            az deployment sub create `
                --location francecentral `
                --template-file ./azure-deploy/main.bicep `
                --parameters $bicepParams `
                --name "TechNova-Main-Deploy-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
                --output none
            
            if ($LASTEXITCODE -ne 0) { throw "Azure CLI deployment failed (Exit code $LASTEXITCODE)." }
        } else {
            New-AzSubscriptionDeployment `
                -Location "francecentral" `
                -TemplateFile "./azure-deploy/main.bicep" `
                -TemplateParameterObject $params `
                -Name "TechNova-Main-Deploy-$(Get-Date -Format 'yyyyMMdd-HHmm')"
        }
        
        $deploymentSuccess = $true
        Write-Host "`n>>> DEPLOYMENT USPJEŠNO ZAVRŠEN! <<<" -ForegroundColor Green

        # 2.1 KORAK: Ažuriranje VMSS Instanci (Apply Cloud-Init)
        Write-Host "`n[INFO] Primjenjujem konfiguraciju na VMSS instance..." -ForegroundColor Yellow
        if (Get-Command "az" -ErrorAction SilentlyContinue) {
            try {
                $ids = az vmss list-instances -g "TechNova-RG" -n "technova-vmss" --query "[].instanceId" -o tsv
                if ($ids) {
                    az vmss update-instances -g "TechNova-RG" -n "technova-vmss" --instance-ids "*" --output none
                    Write-Host "Pokrećem 'Reimage' instanci (instalacija App)..." -ForegroundColor Magenta
                    az vmss reimage -g "TechNova-RG" -n "technova-vmss" --instance-ids "*" --output none
                    Write-Host "Instance su osvježene." -ForegroundColor Green
                }
            } catch {
                Write-Host "UPOZORENJE: Auto-update instanci nije uspio: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

    } catch {
        Write-Error "Greška pri Bicep deploymentu (Pokušaj $retryCount): $($_.Exception.Message)"
        if ($retryCount -lt $maxRetries) {
            Write-Host "Čekam 30 sekundi..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        } else {
            Write-Error "Svi pokušaji deploymenta su neuspješni."
            exit 1
        }
    }
} until ($deploymentSuccess -or $retryCount -ge $maxRetries)

# 3. KORAK: Opcionalno - Sigurnosne politike
Write-Host "`n[3/3] Konfiguracija Sigurnosnih politika (Conditional Access)..." -ForegroundColor Cyan
Write-Host "NAPOMENA: Ovaj korak je OPCIONALAN i nije nužan za uspješan deployment infrastrukture." -ForegroundColor Yellow
Write-Host "Zahtijeva Entra ID P1/P2 licencu. Ako koristite besplatni studentski račun, ovaj korak vjerojatno neće uspjeti." -ForegroundColor Gray

$confirmCA = Read-Host "Želite li pokušati konfigurirati napredne sigurnosne politike (MFA/Geo-block)? (Y/N)"
if ($confirmCA -eq 'Y' -or $confirmCA -eq 'y') {
    try {
        . ./scripts/configure_conditional_access.ps1
        Write-Host "Sigurnosne politike su uspješno konfigurirane." -ForegroundColor Green
    } catch {
        Write-Host "INFO: Konfiguracija politika nije uspjela (vjerojatno zbog nedostatka P1 licence). Nastavljam dalje..." -ForegroundColor DarkGray
    }
} else {
    Write-Host "Preskačem konfiguraciju naprednih sigurnosnih politika." -ForegroundColor Gray
}

Write-Host "`n>>> SVI KORACI ZAVRŠENI <<<" -ForegroundColor Green