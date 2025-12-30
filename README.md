# TechNova Solutions - Azure Cloud Migracija

Dobrodošli u repozitorij projekta za modernizaciju IT infrastrukture tvrtke TechNova Solutions.
Ovo rješenje demonstrira implementaciju Infrastructure as Code (IaC) principa koristeći Azure Bicep i PowerShell za potpunu automatizaciju cloud okoline na Microsoft Azure platformi.

Projekt je izrađen u sklopu kolegija "Implementacija računarstva u oblaku" na Sveučilištu Algebra Bernays (2025).

---

## Arhitektura Rješenja

Rješenje je dizajnirano prema Microsoft Well-Architected Framework principima, s naglaskom na sigurnost, automatizaciju i skalabilnost.

![High-Level Architecture](assets/architecture_diagram.png)

### Ključne Komponente

| Komponenta | Tehnologija | Opis |
| :--- | :--- | :--- |
| **Identiteti (IAM)** | **Microsoft Entra ID** | Automatizirano kreiranje grupa (Dev, Sales, Support) i korisnika putem Microsoft Graph API-ja. |
| **Compute (Web)** | **VM Scale Set** | Skalabilni skup Ubuntu VM-ova (Nginx server) iza Load Balancera za visoku dostupnost. |
| **Containeri** | **Azure Kubernetes (AKS)** | **Demonstracijski resurs:** Implementiran k8s klaster koji demonstrira spremnost infrastrukture za kontejnerizaciju aplikacija. |
| **Baza Podataka** | **Azure SQL Database** | **Demonstracijski resurs:** PaaS rješenje za strukturirane podatke, postavljeno kao backend komponenta rješenja. |
| **Mreža** | **Azure VNet** | Segmentirana mreža (Frontend, Backend, Management subnets) zaštićena NSG-ovima. |
| **Sigurnost & Backup** | **Recovery Services Vault** | **Demonstracijski resurs:** Uspostavljen sustav za centralizirani backup i oporavak podataka. |
| **Automatizacija** | **Bicep & PowerShell** | Potpuni One-Click Deploy i Destroy procesi. |

*Napomena: Resursi označeni kao "Demonstracijski" su u potpunosti provizionirani i konfigurirani na razini infrastrukture kako bi se prikazala arhitekturalna cjelovitost rješenja, iako ih osnovna web aplikacija u ovoj fazi PoC-a (Proof of Concept) ne koristi aktivno.*

---

## Preduvjeti (Prerequisites)

Prije početka, osigurajte da na svom računalu imate instalirane sljedeće alate.

### 1. Instalacija Alata
*   **Visual Studio Code**: Preporučeni editor.
    *   Instalirajte "Bicep" ekstenziju unutar VS Code editora.
*   **PowerShell 7+**: Preporučena verzija terminala (cross-platform).
*   **Azure CLI**: Alat za upravljanje Azure resursima.
*   **Git**: Za preuzimanje repozitorija.

### 2. Provjera Instalacije
Otvorite terminal (PowerShell) i pokrenite sljedeće naredbe:
```powershell
az --version       # Provjera Azure CLI verzije
$PSVersionTable    # Provjera PowerShell verzije
git --version      # Provjera git verzije
```

---

## Upute za Pokretanje (Deployment Guide)

### Korak 1: Preuzimanje Repozitorija
Klonirajte ovaj javni repozitorij na svoje lokalno računalo. Za ovaj korak nije potrebna prijava:
```powershell
git clone https://github.com/krebor/technova-solutions.git
cd technova-solutions
```

### Korak 2: Pokretanje Deploymenta
Ovo rješenje koristi Smart Login sustav koji provjerava postojeće sesije i pamti konfiguraciju.

1.  Pokrenite glavnu skriptu:
    ```powershell
    ./deploy.ps1
    ```

2.  **Prvo pokretanje:** Skripta će tražiti unos **Tenant ID**-a.
    *   Unesite domenu ili GUID vašeg tenanta (npr. `ime.prezime.onmicrosoft.com`).
    *   Podatak će biti spremljen lokalno te ga kod idućih pokretanja nećete morati ponovno unositi.

3.  **Proces:**
    *   Skripta provodi autentikaciju na Azure i Microsoft Graph servisima.
    *   Automatizirano se kreiraju korisnici i grupe u Entra ID-u.
    *   Inicira se Bicep deployment (predviđeno trajanje: 10-15 minuta).

4.  **Završetak:**
    *   Deployment je uspješan kada se u terminalu pojavi poruka: `>>> DEPLOYMENT USPJEŠNO ZAVRŠEN! <<<`.

---

## Verifikacija Rješenja

### 1. Web Aplikacija
Pristupite aplikaciji putem javne IP adrese Load Balancera (ispisana u terminalu ili vidljiva na Portalu pod `technova-lb-pip`):
`http://<IP-ADRESA>`

### 2. Azure Portal
Provjerite Resource Grupu **TechNova-RG**. Svi resursi moraju biti u stanju "Succeeded".

### 3. Entra ID (Identiteti)
Provjerite jesu li u Microsoft Entra ID servisu kreirane grupe `TechNova-Dev`, `TechNova-Sales` i `TechNova-Support` s pripadajućim korisnicima.

---

## Čišćenje (Clean Up)

Kako biste spriječili nepotrebne troškove i oslobodili kvote na studentskoj pretplati, nakon testiranja uklonite resurse.

Pokrenite skriptu:
```powershell
./destroy.ps1
```
Ova skripta će sinkrono obrisati cijelu Resource Grupu i sve kreirane identitete iz Entra ID-a.

---

## Struktura Projekta

```text
.
├── deploy.ps1                 # Glavna skripta za deployment
├── destroy.ps1                # Skripta za brisanje okoline
├── README.md                  # Dokumentacija rješenja
├── azure-deploy/              # Bicep Infrastructure-as-Code
│   ├── main.bicep             # Glavna orkestracija resursa
│   └── modules/               # Modularne Bicep komponente
└── scripts/                   # PowerShell pomoćne skripte
```

---

**Autor:** Krešimir Borbaš  
**Institucija:** Sveučilište Algebra Bernays 
**Godina:** 2025.
