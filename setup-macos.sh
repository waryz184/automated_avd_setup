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
        13)
            PLATFORM_VERSION="33"
            ;;
        14)
            PLATFORM_VERSION="34"
            ;;
        15)
            # L'API level pour Android 15 est 35
            PLATFORM_VERSION="35"
            ;;
        16)
            # L'API level pour Android 16 sera probablement 36
            PLATFORM_VERSION="36"
            ;;
        *)
            echo "Erreur : Version '$ANDROID_VERSION_INPUT' non supportée."
            exit 1
            ;;
    esac

    AVD_NAME="android-${ANDROID_VERSION_INPUT}-vm"
    # Détection de l'architecture pour Apple Silicon (arm64) vs Intel (x86_64)
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        SYSTEM_IMAGE="system-images;android-${PLATFORM_VERSION};google_apis;arm64-v8a"
    else
        SYSTEM_IMAGE="system-images;android-${PLATFORM_VERSION};google_apis;x86_64"
    fi
    success "Configuration pour Android $ANDROID_VERSION_INPUT (API $PLATFORM_VERSION) sur arch $ARCH."
}

# Vérifie les dépendances système comme Homebrew
check_dependencies() {
    step "Vérification des dépendances..."
    if ! command_exists brew; then
        echo "Erreur : Homebrew n'est pas installé. Veuillez l'installer depuis https://brew.sh/"
        exit 1
    fi
    success "Homebrew est installé."
}

# Installe Java via Homebrew si nécessaire
install_java() {
    if ! command_exists java; then
        step "Installation de Java (OpenJDK)..."
        brew install openjdk
        
        # Homebrew nécessite une étape manuelle pour lier le JDK
        echo -e "\n${BLUE}--- ACTION REQUISE ---${NC}"
        echo "Pour finaliser l'installation de Java, veuillez exécuter la commande suivante dans un autre terminal :"
        echo -e "${GREEN}sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk${NC}"
        read -p "Appuyez sur Entrée une fois que c'est fait..."
    fi
    success "Java est installé et configuré."
}

# Installe les outils de ligne de commande du SDK Android
install_sdk_tools() {
    if [ -d "$SDK_ROOT_DIR" ]; then
        success "Le dossier du SDK Android existe déjà."
        return
    fi
    
    step "Téléchargement des outils de ligne de commande du SDK Android..."
    local LATEST_URL="https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip"
    local ZIP_FILE="cmdline-tools.zip"
    
    curl -L -o "$ZIP_FILE" "$LATEST_URL"
    
    step "Organisation de la structure du SDK..."
    unzip -q "$ZIP_FILE" -d "$SDK_ROOT_DIR"
    rm "$ZIP_FILE"
    
    # Crée la structure de dossier moderne attendue par sdkmanager
    mkdir -p "$SDK_ROOT_DIR/cmdline-tools"
    mv "$SDK_ROOT_DIR/cmdline-tools" "$SDK_ROOT_DIR/latest"
    mkdir "$SDK_ROOT_DIR/cmdline-tools"
    mv "$SDK_ROOT_DIR/latest" "$SDK_ROOT_DIR/cmdline-tools/"

    success "Outils du SDK installés dans $SDK_ROOT_DIR"
}

# Configure les variables d'environnement dans .zshrc
setup_environment_variables() {
    step "Configuration des variables d'environnement..."
    local ZSHRC_FILE="$HOME/.zshrc"
    
    if ! grep -q "ANDROID_HOME" "$ZSHRC_FILE"; then
        echo "Ajout des variables au fichier $ZSHRC_FILE..."
        echo -e "\n# Android SDK Setup" >> "$ZSHRC_FILE"
        echo "$ANDROID_HOME_VAR" >> "$ZSHRC_FILE"
        echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' >> "$ZSHRC_FILE"
        echo 'export PATH="$ANDROID_HOME/platform-tools:$PATH"' >> "$ZSHRC_FILE"
        echo 'export PATH="$ANDROID_HOME/emulator:$PATH"' >> "$ZSHRC_FILE"
        success "Variables d'environnement ajoutées."
        echo "Veuillez ouvrir un nouveau terminal après la fin du script pour les utiliser."
    else
        success "Les variables d'environnement semblent déjà configurées."
    fi
}

# Installe les paquets Android nécessaires (émulateur, image système...)
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

    step "Activation du clavier physique pour l'AVD..."
    # Append the keyboard setting. The emulator uses the last entry for a given key.
    echo "hw.keyboard=yes" >> "$HOME/.android/avd/$AVD_NAME.avd/config.ini"
    success "Clavier physique activé."
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
    echo -e "${GREEN}$SDK_ROOT_DIR/emulator/emulator @$AVD_NAME${NC}"
}

main
