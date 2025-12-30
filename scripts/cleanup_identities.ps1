# Brisanje korisnika i grupa kreiranih za projekt
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All" -NoWelcome
}

$users = @("ivan.dev", "ana.sales", "marko.support")
$groups = @("TechNova-Dev", "TechNova-Sales", "TechNova-Support")

foreach ($u in $users) {
    # Tražimo po MailNickname jer nemamo puni UPN hardkodiran
    $userObj = Get-MgUser -Filter "MailNickname eq '$u'" -ErrorAction SilentlyContinue
    if ($userObj) {
        Remove-MgUser -UserId $userObj.Id -ErrorAction SilentlyContinue
        Write-Host "Obrisan korisnik: $u" -ForegroundColor Yellow
    }
}

foreach ($g in $groups) {
    $groupObj = Get-MgGroup -Filter "DisplayName eq '$g'" -ErrorAction SilentlyContinue
    if ($groupObj) {
        Remove-MgGroup -GroupId $groupObj.Id -ErrorAction SilentlyContinue
        Write-Host "Obrisana grupa: $g" -ForegroundColor Yellow
    }
}
