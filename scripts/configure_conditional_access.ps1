if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess", "Agreement.Read.All"
}

# 1. Definiranje "Named Location" za Hrvatsku
# Conditional Access treba znati što je "Hrvatska" po IP adresama
$croatiaLocation = New-MgIdentityConditionalAccessNamedLocation -DisplayName "Allowed Countries (HR)" `
  -IsTrusted $true `
  -CountriesAndRegions @{
    includeCountriesAndRegions = @("HR")
  }

Write-Host "Kreirana lokacija: Hrvatska (ID: $($croatiaLocation.Id))" -ForegroundColor Green

# 2. Kreiranje Politike: Blokiraj sve izvan Hrvatske
# Logika: Ako lokacija NIJE Hrvatska -> BLOKIRAJ
$conditions = @{
  Applications = @{ includeApplications = @("All") }
  Users = @{ includeUsers = @("All") }
  Locations = @{
    includeLocations = @("All")
    excludeLocations = @($croatiaLocation.Id)
  }
}

$grantControl = @{
  BuiltInControls = @("block")
  Operator = "OR"
}

New-MgIdentityConditionalAccessPolicy -DisplayName "Block-Non-HR-Access" `
  -State "enabled" `
  -Conditions $conditions `
  -GrantControls $grantControl

Write-Host "Kreirana politika: Blokiraj pristup izvan Hrvatske" -ForegroundColor Green

# 3. Kreiranje Politike: MFA za Administratore
# Logika: Ako je korisnik u grupi 'TechNova-Dev' -> Traži MFA
$devGroupId = (Get-MgGroup -Filter "DisplayName eq 'TechNova-Dev'").Id

$mfaConditions = @{
  Applications = @{ includeApplications = @("All") }
  Users = @{ includeGroups = @($devGroupId) }
}

$mfaGrant = @{
  BuiltInControls = @("mfa")
  Operator = "OR"
}

New-MgIdentityConditionalAccessPolicy -DisplayName "Require-MFA-For-Devs" `
  -State "enabled" `
  -Conditions $mfaConditions `
  -GrantControls $mfaGrant

Write-Host "Kreirana politika: Obavezan MFA za Dev tim" -ForegroundColor Green
