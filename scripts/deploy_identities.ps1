# Opis: Skripta za kreiranje Entra ID korisnika i grupa za TechNova projekt

# 1. Prijava na Microsoft Graph
Write-Host "Provjera Microsoft Graph prijave..." -ForegroundColor Cyan
if (-not (Get-MgContext)) {
    Write-Host "Niste prijavljeni. Spajanje na Microsoft Graph..."
    # Dodan 'Domain.Read.All' kako bi mogli dohvatiti naziv tenanta
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Domain.Read.All" -NoWelcome
} else {
    Write-Host "Već ste prijavljeni na Microsoft Graph. Preskačem 'Connect-MgGraph'." -ForegroundColor Green
}

# 2. Definicija profila lozinke
$passwordProfile = @{
    Password = "TechNovaSecurePass123!"
    ForceChangePasswordNextSignIn = $false
}

# 3. Funkcija za sigurno kreiranje grupe
function New-TechNovaGroup {
    param ($Name, $Nick)
    try {
        $group = Get-MgGroup -Filter "DisplayName eq '$Name'" -ErrorAction Stop
        if ($group -is [array]) { $group = $group | Select-Object -First 1 }
    } catch {
        $group = $null
    }
    
    if (-not $group) {
        try {
            $groupParams = @{
                DisplayName = $Name
                MailEnabled = $false
                SecurityEnabled = $true
                MailNickname = $Nick
            }
            $group = New-MgGroup -BodyParameter $groupParams -ErrorAction Stop
            Write-Host "USPJEH: Kreirana grupa '$Name'" -ForegroundColor Green
        } catch {
            Write-Host "GREŠKA: Nije uspjelo kreiranje grupe '$Name'. Detalji: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "INFO: Grupa '$Name' već postoji." -ForegroundColor Yellow
    }
    return $group
}

# 4. Funkcija za sigurno kreiranje korisnika
function New-TechNovaUser {
    param ($UPN, $Name, $Nick)
    
    # Provjera postoji li korisnik
    try {
        $user = Get-MgUser -Filter "UserPrincipalName eq '$UPN'" -ErrorAction SilentlyContinue
    } catch {
        $user = $null
    }
    
    if (-not $user) {
        try {
            $userParams = @{
                DisplayName = $Name
                UserPrincipalName = $UPN
                PasswordProfile = $passwordProfile
                AccountEnabled = $true
                MailNickname = $Nick
            }
            # Ovdje se događa kreiranje. Ako padne, ide u catch blok.
            $user = New-MgUser -BodyParameter $userParams -ErrorAction Stop
            Write-Host "USPJEH: Kreiran korisnik '$Name' ($UPN)" -ForegroundColor Green
        } catch {
            Write-Host "GREŠKA: Nije uspjelo kreiranje korisnika '$Name'. Detalji: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    } else {
        Write-Host "INFO: Korisnik '$Name' već postoji." -ForegroundColor Yellow
    }
    return $user
}

# --- IZVRŠAVANJE ---

# Dohvat domene tenanta
try {
    $domainObj = Get-MgDomain | Where-Object { $_.IsDefault }
    if ($null -eq $domainObj) {
        throw "Nije pronađena defaultna domena."
    }
    $domain = $domainObj.Id
    Write-Host "Koristim domenu: $domain" -ForegroundColor Gray
} catch {
    Write-Host "KRITIČNA GREŠKA: Nemoguće dohvatiti domenu tenanta." -ForegroundColor Red
    Write-Host "Detalji greške: $($_.Exception.Message)" -ForegroundColor Red
    
    # Debug info
    $ctx = Get-MgContext
    if ($ctx) {
        Write-Host "Debug Info:" -ForegroundColor DarkGray
        Write-Host "  TenantId: $($ctx.TenantId)" -ForegroundColor DarkGray
        Write-Host "  Scopes:   $($ctx.Scopes -join ', ')" -ForegroundColor DarkGray
        Write-Host "  Account:  $($ctx.Account)" -ForegroundColor DarkGray
    } else {
        Write-Host "Debug Info: Nema aktivnog Graph konteksta!" -ForegroundColor Red
    }

    exit 1 # Prekidamo izvršavanje
}

# Kreiranje Grupa
$devGroup = New-TechNovaGroup -Name "TechNova-Dev" -Nick "technova-dev"
$salesGroup = New-TechNovaGroup -Name "TechNova-Sales" -Nick "technova-sales"
$suppGroup = New-TechNovaGroup -Name "TechNova-Support" -Nick "technova-support"

Write-Host "`n[INFO] Detektirani Identiteti za Deployment:" -ForegroundColor Cyan
if ($devGroup) { Write-Host "  > Dev Group ID:   $($devGroup.Id)" -ForegroundColor Gray }
if ($salesGroup) { Write-Host "  > Sales Group ID: $($salesGroup.Id)" -ForegroundColor Gray }
if ($suppGroup) { Write-Host "  > Support Group ID: $($suppGroup.Id)" -ForegroundColor Gray }
Write-Host ""

# Kreiranje Korisnika
$uDev = New-TechNovaUser -UPN "ivan.dev@$domain" -Name "Ivan Horvat (Dev)" -Nick "ivan.dev"
$uSales = New-TechNovaUser -UPN "ana.sales@$domain" -Name "Ana Marić (Sales)" -Nick "ana.sales"
$uSupport = New-TechNovaUser -UPN "marko.support@$domain" -Name "Marko Ivić (Support)" -Nick "marko.support"

# Dodavanje u grupe
# Pomoćna funkcija za dodavanje
function Add-UserToGroupSafe {
    param ($Group, $User, $GroupName)
    if ($Group -and $User) {
        try {
            New-MgGroupMember -GroupId $Group.Id -DirectoryObjectId $User.Id -ErrorAction Stop
            Write-Host "POVEZANO: Korisnik dodan u grupu $GroupName." -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -like "*already exist*") {
                Write-Host "INFO: Korisnik je već član grupe $GroupName." -ForegroundColor DarkGray
            } else {
                Write-Host "GREŠKA pri dodavanju u grupu ${GroupName}: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "UPOZORENJE: Preskačem dodavanje u grupu $GroupName jer grupa ili korisnik nisu kreirani." -ForegroundColor Magenta
    }
}

Add-UserToGroupSafe -Group $devGroup -User $uDev -GroupName "TechNova-Dev"
Add-UserToGroupSafe -Group $salesGroup -User $uSales -GroupName "TechNova-Sales"
Add-UserToGroupSafe -Group $suppGroup -User $uSupport -GroupName "TechNova-Support"

# Output objects for Orchestrator (Script Scope)
Write-Host "Postavljam varijable identiteta..." -ForegroundColor Cyan

# Postavljamo varijable u Script Scope kako bi bile vidljive roditeljskoj skripti kod Dot-Sourcinga
$script:DevGroupId     = "$($devGroup.Id)"
$script:SalesGroupId   = "$($salesGroup.Id)"
$script:SupportGroupId = "$($suppGroup.Id)"

Write-Host "Identiteti su spremni." -ForegroundColor Green
