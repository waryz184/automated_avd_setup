#!/bin/bash

# Arrête le script si une commande échoue
set -e

# --- Variables et Constantes ---
BLUE="\033[1;34m"
GREEN="\033[1;32m"
NC="\033[0m" # No Color

ANDROID_VERSION_INPUT=$1
AVD_NAME=""
PLATFORM_VERSION=""
SYSTEM_IMAGE=""

SDK_ROOT_DIR="$(pwd)/sdk"
ANDROID_HOME_VAR="export ANDROID_HOME=\"$SDK_ROOT_DIR\""

# --- Fonctions ---

# Affiche un message d'étape
step() {
    echo -e "\n${BLUE}==> $1${NC}"
}

# Affiche un message de succès
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Vérifie la présence d'une commande
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Valide l'argument d'entrée et configure les variables de version
validate_input() {
    step "Validation de la version d'Android..."
    if [ -z "$ANDROID_VERSION_INPUT" ]; then
        echo "Erreur : Vous devez spécifier une version d'Android."
        echo "Usage: ./setup.sh <version>"
        echo "Versions supportées: 13, 14, 15, 16"
        exit 1
    fi

    case $ANDROID_VERSION_INPUT in
        13) PLATFORM_VERSION="33" ;; 
        14) PLATFORM_VERSION="34" ;; 
        15) PLATFORM_VERSION="35" ;; 
        16) PLATFORM_VERSION="36" ;; 
        *) echo "Erreur : Version '$ANDROID_VERSION_INPUT' non supportée." ; exit 1 ;; 
    esac

    AVD_NAME="android-${ANDROID_VERSION_INPUT}-vm"
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        SYSTEM_IMAGE="system-images;android-${PLATFORM_VERSION};google_apis;arm64-v8a"
    elif [ "$ARCH" = "x86_64" ]; then
        SYSTEM_IMAGE="system-images;android-${PLATFORM_VERSION};google_apis;x86_64"
    else
        echo "Erreur: Architecture non supportée: $ARCH" ; exit 1
    fi
    success "Configuration pour Android $ANDROID_VERSION_INPUT (API $PLATFORM_VERSION) sur arch $ARCH."
}

# Vérifie les dépendances système
check_dependencies() {
    step "Vérification des dépendances..."
    if ! command_exists apt-get; then
        echo "Attention : Ce script est optimisé pour les systèmes Debian/Ubuntu (utilisant apt-get)."
        echo "Vous devrez peut-être adapter l'installation de Java pour votre distribution."
    fi
    if ! command_exists unzip; then
        echo "Installation de 'unzip'..."
        sudo apt-get update && sudo apt-get install -y unzip
    fi
    success "Dépendances vérifiées."
}

# Installe Java si nécessaire
install_java() {
    if ! command_exists java; then
        step "Installation de Java (OpenJDK 17)..."
        sudo apt-get update && sudo apt-get install -y openjdk-17-jdk
    fi
    success "Java est installé."
}

# Installe les outils de ligne de commande du SDK Android
install_sdk_tools() {
    if [ -d "$SDK_ROOT_DIR" ]; then
        success "Le dossier du SDK Android existe déjà."
        return
    fi
    
    step "Téléchargement des outils de ligne de commande du SDK Android pour Linux..."
    local LATEST_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
    local ZIP_FILE="cmdline-tools.zip"
    
    curl -L -o "$ZIP_FILE" "$LATEST_URL"
    
    step "Organisation de la structure du SDK..."
    unzip -q "$ZIP_FILE" -d "$SDK_ROOT_DIR"
    rm "$ZIP_FILE"
    
    mkdir -p "$SDK_ROOT_DIR/cmdline-tools"
    mv "$SDK_ROOT_DIR/cmdline-tools" "$SDK_ROOT_DIR/latest"
    mkdir "$SDK_ROOT_DIR/cmdline-tools"
    mv "$SDK_ROOT_DIR/latest" "$SDK_ROOT_DIR/cmdline-tools/"

    success "Outils du SDK installés dans $SDK_ROOT_DIR"
}

# Configure les variables d'environnement
setup_environment_variables() {
    step "Configuration des variables d'environnement..."
    local SHELL_CONFIG_FILE=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_CONFIG_FILE="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_CONFIG_FILE="$HOME/.bashrc"
    else
        echo "Attention: Impossible de trouver .zshrc ou .bashrc. Vous devrez configurer les variables d'environnement manuellement."
        return
    fi

    if ! grep -q "ANDROID_HOME" "$SHELL_CONFIG_FILE"; then
        echo "Ajout des variables au fichier $SHELL_CONFIG_FILE..."
        echo -e "\n# Android SDK Setup" >> "$SHELL_CONFIG_FILE"
        echo "$ANDROID_HOME_VAR" >> "$SHELL_CONFIG_FILE"
        echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' >> "$SHELL_CONFIG_FILE"
        echo 'export PATH="$ANDROID_HOME/platform-tools:$PATH"' >> "$SHELL_CONFIG_FILE"
        echo 'export PATH="$ANDROID_HOME/emulator:$PATH"' >> "$SHELL_CONFIG_FILE"
        success "Variables d'environnement ajoutées."
        echo "Veuillez sourcer votre $SHELL_CONFIG_FILE ou ouvrir un nouveau terminal après la fin du script."
    else
        success "Les variables d'environnement semblent déjà configurées."
    fi
}

# Installe les paquets Android nécessaires
install_android_packages() {
    step "Acceptation des licences du SDK..."
    yes | "$SDK_ROOT_DIR/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null

    step "Installation des paquets Android (cela peut prendre du temps)..."
    "$SDK_ROOT_DIR/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "emulator" "platforms;android-${PLATFORM_VERSION}" "${SYSTEM_IMAGE}"

    success "Paquets Android installés."
}

# Crée la machine virtuelle (AVD)
create_avd() {
    step "Création de la machine virtuelle (AVD)..."
    if "$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: $AVD_NAME"; then
        success "L'AVD '$AVD_NAME' existe déjà."
        return
    fi

    echo "no" | "$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" create avd -n "$AVD_NAME" -k "${SYSTEM_IMAGE}"
    success "AVD '$AVD_NAME' créée."
}

# --- Exécution Principale ---
main() {
    validate_input
    check_dependencies
    install_java
    install_sdk_tools
    setup_environment_variables
    install_android_packages
    create_avd

    step "Installation terminée !"
    echo -e "Pour lancer votre machine virtuelle, ouvrez un ${GREEN}NOUVEAU TERMINAL${NC} et tapez :"
    echo -e "${GREEN}emulator @$AVD_NAME${NC}"
}

main
