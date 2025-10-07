# Ce script est conçu pour PowerShell sur Windows.
# Il se peut que vous deviez autoriser son exécution en lançant d'abord cette commande dans votre terminal PowerShell :
# Set-ExecutionPolicy RemoteSigned -Scope Process -Force

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Version d'Android à installer (ex: 13, 14, 15, 16)")]
    [string]$AndroidVersionInput
)

# --- Variables et Constantes ---
$sdkRootDir = "$PSScriptRoot\sdk"

$avdName = ""
$platformVersion = ""
$systemImage = ""

# --- Fonctions ---

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "Error: $Message" -ForegroundColor Red
    exit 1
}

# Valide l'argument d'entrée et configure les variables de version
function Validate-Input {
    Write-Step "Validation de la version d'Android..."
    
    switch ($AndroidVersionInput) {
        "13" { $platformVersion = "33" }
        "14" { $platformVersion = "34" }
        "15" { $platformVersion = "35" }
        "16" { $platformVersion = "36" }
        default { Write-Error "Version '$AndroidVersionInput' non supportée." }
    }

    $avdName = "android-$AndroidVersionInput-vm"
    
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq 'ARM64') {
        $systemImage = "system-images;android-$platformVersion;google_apis_playstore;arm64-v8a"
    } elseif ($arch -eq 'AMD64') {
        $systemImage = "system-images;android-$platformVersion;google_apis_playstore;x86_64"
    } else {
        Write-Error "Architecture non supportée: $arch"
    }

    Write-Success "Configuration pour Android $AndroidVersionInput (API $platformVersion) sur arch $arch."
}

# Vérifie les dépendances comme Chocolatey
function Check-Dependencies {
    Write-Step "Vérification des dépendances..."
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Error "Chocolatey n'est pas installé. Veuillez l'installer depuis https://chocolatey.org/install"
    }
    Write-Success "Chocolatey est installé."
}

# Installe Java via Chocolatey si nécessaire
function Install-Java {
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        Write-Step "Installation de Java (OpenJDK 17)..."
        choco install openjdk --version=17 -y
    }
    Write-Success "Java est installé."
}

# Installe les outils de ligne de commande du SDK Android
function Install-Sdk-Tools {
    if (Test-Path -Path $sdkRootDir) {
        Write-Success "Le dossier du SDK Android existe déjà."
        return
    }
    
    Write-Step "Téléchargement des outils de ligne de commande du SDK Android pour Windows..."
    $latestUrl = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
    $zipFile = "$PSScriptRoot\cmdline-tools.zip"
    
    Invoke-WebRequest -Uri $latestUrl -OutFile $zipFile
    
    Write-Step "Organisation de la structure du SDK..."
    Expand-Archive -Path $zipFile -DestinationPath $sdkRootDir
    Remove-Item -Path $zipFile
    
    $toolsDir = Join-Path $sdkRootDir "cmdline-tools"
    $latestDir = Join-Path $toolsDir "latest"
    New-Item -ItemType Directory -Path $latestDir -Force
    Move-Item -Path (Join-Path $toolsDir "*") -Destination $latestDir -Force

    Write-Success "Outils du SDK installés dans $sdkRootDir"
}

# Configure les variables d'environnement
function Setup-Environment-Variables {
    Write-Step "Configuration des variables d'environnement..."
    
    $currentUserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $androidHomeInPath = $currentUserPath -like "*$sdkRootDir*"

    if (-not $androidHomeInPath) {
        Write-Host "Ajout des variables d'environnement pour l'utilisateur actuel..."
        [System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkRootDir, 'User')
        
        $newPath = "$currentUserPath;${sdkRootDir}\emulator;${sdkRootDir}\platform-tools;${sdkRootDir}\cmdline-tools\latest\bin"
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        
        Write-Success "Variables d'environnement ajoutées."
        Write-Host "Veuillez ouvrir un nouveau terminal PowerShell après la fin du script pour les utiliser."
    } else {
        Write-Success "Les variables d'environnement semblent déjà configurées."
    }
}

# Installe les paquets Android nécessaires
function Install-Android-Packages {
    $sdkManager = Join-Path $sdkRootDir "cmdline-tools\latest\bin\sdkmanager.bat"
    Write-Step "Acceptation des licences du SDK..."
    "yes" | & $sdkManager --licenses > $null

    Write-Step "Installation des paquets Android (cela peut prendre du temps)..."
    & $sdkManager "platform-tools" "emulator" "platforms;android-$platformVersion" "$systemImage"

    Write-Success "Paquets Android installés."
}

# Crée la machine virtuelle (AVD)
function Create-Avd {
    $avdManager = Join-Path $sdkRootDir "cmdline-tools\latest\bin\avdmanager.bat"
    Write-Step "Création de la machine virtuelle (AVD)..."
    
    $avdList = & $avdManager list avd
    if ($avdList -match "Name: $avdName") {
        Write-Success "L'AVD '$avdName' existe déjà."
        return
    }

    "no" | & $avdManager create avd -n $avdName -k $systemImage
    Write-Success "AVD '$avdName' créée."
}

# --- Exécution Principale ---
function Main {
    Validate-Input
    Check-Dependencies
    Install-Java
    Install-Sdk-Tools
    Setup-Environment-Variables
    Install-Android-Packages
    Create-Avd

    Write-Step "Installation terminée !"
    Write-Host "Pour lancer votre machine virtuelle, ouvrez un NOUVEAU TERMINAL et tapez :" -ForegroundColor Yellow
    Write-Host "emulator @$avdName" -ForegroundColor Green
}

Main
