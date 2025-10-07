#!/bin/bash

# Arrête le script si une commande échoue
set -e

# --- Gum Styles ---
gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Automated AVD Setup pour Linux"

# --- Variables Globales ---
SDK_ROOT_DIR="$(pwd)/sdk"

# --- Fonctions ---

# Vérifie la présence de Gum et guide pour son installation si absent
require_gum() {
    if ! command -v gum >/dev/null 2>&1;
then
        echo "Erreur: 'gum' n'est pas installé."
        echo "Cet outil est nécessaire pour l'interface interactive."
        echo "Veuillez l'installer depuis le gestionnaire de paquets de votre distribution ou depuis les releases GitHub :"
        gum style --bold "https://github.com/charmbracelet/gum/releases"
        exit 1
    fi
}

# Affiche un message d'étape
step() {
    gum style --foreground 33 "==> $1"
}

# Affiche un message de succès
success() {
    gum style --foreground 40 "✓ $1"
}

# Vérifie la présence d'une commande
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Vérifie les dépendances système
check_dependencies() {
    step "Vérification des dépendances..."
    if ! command_exists apt-get;
then
        gum style --faint "Attention : Ce script est optimisé pour les systèmes Debian/Ubuntu (utilisant apt-get)."
        gum style --faint "Vous devrez peut-être adapter l'installation de Java pour votre distribution."
    fi
    if ! command_exists unzip;
then
        if gum confirm "La commande 'unzip' est manquante. Voulez-vous l'installer ?"; then
            sudo apt-get update && sudo apt-get install -y unzip
        else
            echo "Installation annulée."
            exit 1
        fi
    fi
    success "Dépendances vérifiées."
}

# Installe Java si nécessaire
install_java() {
    if ! command_exists java;
then
        step "Installation de Java (OpenJDK 17)..."
        gum spin --spinner dot --title "Installation de OpenJDK 17..." -- sudo apt-get update && sudo apt-get install -y openjdk-17-jdk
    fi
    success "Java est installé."
}

# Installe les outils de ligne de commande du SDK Android
install_sdk_tools() {
    if [ -d "$SDK_ROOT_DIR" ]; then
        success "Le dossier du SDK Android existe déjà."
        return
    fi
    
    local LATEST_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
    local ZIP_FILE="cmdline-tools.zip"
    
    gum spin --spinner dot --title "Téléchargement des outils SDK..." -- curl -L -o "$ZIP_FILE" "$LATEST_URL"
    
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
        gum style --bold --foreground 203 "Attention: Impossible de trouver .zshrc ou .bashrc."
        echo "Vous devrez configurer les variables d'environnement manuellement."
        return
    fi

    if ! grep -q "ANDROID_HOME" "$SHELL_CONFIG_FILE"; then
        echo "Ajout des variables au fichier $SHELL_CONFIG_FILE..."
        {
            echo -e "\n# Android SDK Setup"
            echo "export ANDROID_HOME=\"$SDK_ROOT_DIR\""
            echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"'
            echo 'export PATH="$ANDROID_HOME/platform-tools:$PATH"'
            echo 'export PATH="$ANDROID_HOME/emulator:$PATH"'
        } >> "$SHELL_CONFIG_FILE"
        success "Variables d'environnement ajoutées."
        gum style --bold "Veuillez sourcer votre $SHELL_CONFIG_FILE ou ouvrir un nouveau terminal."
    else
        success "Les variables d'environnement semblent déjà configurées."
    fi
}

# Installe les paquets Android nécessaires
install_android_packages() {
    step "Acceptation des licences du SDK..."
    yes | "$SDK_ROOT_DIR/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null

    step "Installation des paquets Android (cela peut prendre du temps)..."
    gum spin --spinner dot --title "Installation des paquets..." -- "$SDK_ROOT_DIR/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "emulator" "platforms;android-${PLATFORM_VERSION}" "${SYSTEM_IMAGE}"

    success "Paquets Android installés."
}

# Crée la machine virtuelle (AVD)
create_avd() {
    step "Création de la machine virtuelle (AVD)..."
    if "$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: $AVD_NAME"; then
        if gum confirm "L'AVD '$AVD_NAME' existe déjà. Voulez-vous la recréer ?"; then
            "$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" delete avd -n "$AVD_NAME"
        else
            success "Création ignorée."
            return
        fi
    fi

    gum spin --spinner dot --title "Création de l'AVD '$AVD_NAME'..." -- echo "no" | "$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" create avd -n "$AVD_NAME" -k "${SYSTEM_IMAGE}"
    success "AVD '$AVD_NAME' créée."
}

# Supprime les AVDs sélectionnés par l'utilisateur
delete_avd() {
    step "Suppression d'AVDs existants..."
    
    if [ ! -d "$SDK_ROOT_DIR/cmdline-tools" ]; then
        gum style --bold --foreground 203 "Le SDK Android n'est pas installé. Impossible de lister les AVDs."
        echo "Veuillez d'abord exécuter l'installation."
        exit 1
    fi

    AVD_LIST=$("$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" list avd | grep "Name: " | sed 's/Name: //')

    if [ -z "$AVD_LIST" ]; then
        success "Aucun AVD trouvé."
        exit 0
    fi

    gum style --bold "Sélectionnez les AVDs à supprimer (Espace pour sélectionner, Entrée pour confirmer):"
    AVDS_TO_DELETE=$(echo "$AVD_LIST" | gum choose --no-limit)

    if [ -z "$AVDS_TO_DELETE" ]; then
        echo "Aucun AVD sélectionné. Annulation."
        exit 0
    fi

    if gum confirm "Êtes-vous sûr de vouloir supprimer les AVDs suivants ?\n\n$AVDS_TO_DELETE"; then
        echo "$AVDS_TO_DELETE" | while IFS= read -r avd_name; do
            step "Suppression de '$avd_name'..."
            "$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" delete avd -n "$avd_name"
            success "'$avd_name' supprimé."
        done
    else
        echo "Suppression annulée."
    fi
}

# Lance un AVD sélectionné par l'utilisateur
launch_avd() {
    step "Lancement d'un AVD existant..."

    if [ ! -d "$SDK_ROOT_DIR/cmdline-tools" ]; then
        gum style --bold --foreground 203 "Le SDK Android n'est pas installé. Impossible de lister les AVDs."
        echo "Veuillez d'abord exécuter l'installation."
        exit 1
    fi

    AVD_LIST=$("$SDK_ROOT_DIR/cmdline-tools/latest/bin/avdmanager" list avd | grep "Name: " | sed 's/Name: //')

    if [ -z "$AVD_LIST" ]; then
        success "Aucun AVD trouvé à lancer."
        exit 0
    fi

    gum style --bold "Sélectionnez un AVD à lancer :"
    AVD_TO_LAUNCH=$(echo "$AVD_LIST" | gum choose)

    if [ -n "$AVD_TO_LAUNCH" ]; then
        step "Lancement de '$AVD_TO_LAUNCH' en arrière-plan..."
        nohup "$SDK_ROOT_DIR/emulator/emulator" @"$AVD_TO_LAUNCH" >/dev/null 2>&1 &
        success "'$AVD_TO_LAUNCH' est en cours de démarrage. Vous pouvez fermer ce terminal."
    else
        echo "Aucun AVD sélectionné. Annulation."
    fi
}

# Logique d'installation complète
run_installation() {
    if ! gum confirm "Prêt à commencer l'installation de l'AVD Android ?"; then
        echo "Installation annulée."
        exit 0
    fi

    step "Configuration de votre AVD..."
    ANDROID_VERSION_NAME=$(gum choose "Android 16 (Baklava)" "Android 15 (VanillaIceCream)" "Android 14 (UpsideDownCake)" "Android 13 (Tiramisu)")
    
    case $ANDROID_VERSION_NAME in
        "Android 16 (Baklava)") PLATFORM_VERSION="36" ;; 
        "Android 15 (VanillaIceCream)") PLATFORM_VERSION="35" ;; 
        "Android 14 (UpsideDownCake)") PLATFORM_VERSION="34" ;; 
        "Android 13 (Tiramisu)") PLATFORM_VERSION="33" ;; 
    esac

    gum style --bold "Choisissez un type d'image système :"
    IMAGE_CHOICE=$(gum choose \
        "Google Play (Recommandé: Inclut le Play Store et les services Google)" \
        "Google APIs (Services Google, sans le Play Store)" \
        "AOSP - Automated Testing (Android de base, sans services Google)" \
        "Google APIs - Automated Testing (Services Google pour tests automatisés)")

    case "$IMAGE_CHOICE" in
        "Google Play (Recommandé: Inclut le Play Store et les services Google)") IMAGE_TYPE="google_apis_playstore" ;; 
        "Google APIs (Services Google, sans le Play Store)") IMAGE_TYPE="google_apis" ;; 
        "AOSP - Automated Testing (Android de base, sans services Google)") IMAGE_TYPE="aosp_atd" ;; 
        "Google APIs - Automated Testing (Services Google pour tests automatisés)") IMAGE_TYPE="google_atd" ;; 
    esac
    
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        ARCH_SUFFIX="arm64-v8a"
    elif [ "$ARCH" = "x86_64" ]; then
        ARCH_SUFFIX="x86_64"
    else
        echo "Erreur: Architecture non supportée: $ARCH" ; exit 1
    fi
    
    SYSTEM_IMAGE="system-images;android-${PLATFORM_VERSION};${IMAGE_TYPE};${ARCH_SUFFIX}"
    
    gum style --bold "Nom de l'AVD: "
    AVD_NAME=$(gum input --placeholder "android-${PLATFORM_VERSION}-vm")
    if [ -z "$AVD_NAME" ]; then
        AVD_NAME="android-${PLATFORM_VERSION}-vm"
    fi

    gum style --border double --padding "1" "Configuration choisie :" "API Level: ${PLATFORM_VERSION}" "Image: ${SYSTEM_IMAGE}" "Nom AVD: ${AVD_NAME}"

    check_dependencies
    install_java
    install_sdk_tools
    setup_environment_variables
    install_android_packages
    create_avd

    step "Installation terminée !"
    gum style --bold --foreground 40 "Pour lancer votre machine virtuelle, ouvrez un NOUVEAU TERMINAL et tapez :"
    echo "emulator @$AVD_NAME"
}

# --- Exécution Principale ---
main() {
    require_gum
    
    ACTION=$(gum choose "Installer un nouvel AVD" "Lancer un AVD existant" "Supprimer des AVDs existants")

    if [ "$ACTION" = "Installer un nouvel AVD" ]; then
        run_installation
    elif [ "$ACTION" = "Lancer un AVD existant" ]; then
        launch_avd
    elif [ "$ACTION" = "Supprimer des AVDs existants" ]; then
        delete_avd
    fi
}

main