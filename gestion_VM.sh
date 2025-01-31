#!/bin/bash

#Configurer ici les chemins vers vos fichiers .vmx des VM 
DEBIAN_VM="/Users/lonelyspirit/Virtual Machines.localized/Debian12.vmwarevm"
WINDOWS_VM="/Users/lonelyspirit/Virtual Machines.localized/Windows10.vmwarevm"

#Adapter l'IP/hostname et l'utilisateur pour SSH sur Debian 
VM_DEBIAN_SSH_IP="192.168.1.32"       # IP/hostname de la VM Debian
VM_DEBIAN_SSH_USER="dduadmin"       # Utilisateur pour Debian

#Adapter l'IP/hostname et l'utilisateur pour SSH sur Windows 
VM_WINDOWS_SSH_IP="192.168.YY.YY"      # IP/hostname de la VM Windows
VM_WINDOWS_SSH_USER="user_windows"     # Utilisateur pour Windows

#Fonctions
demarrer_vm() {
    local vm_path="$1"
    echo "Démarrage de la VM : $vm_path"
    /Applications/VMware\ Fusion.app/Contents/Library/vmrun start "$vm_path"
}

arreter_vm() {
    local vm_path="$1"
    echo "Arrêt de la VM : $vm_path"
    /Applications/VMware\ Fusion.app/Contents/Library/vmrun stop "$vm_path" soft
}

ssh_vm_debian() {
    echo "Ouverture d'une session SSH vers ${VM_DEBIAN_SSH_USER}@${VM_DEBIAN_SSH_IP}"
    ssh "${VM_DEBIAN_SSH_USER}@${VM_DEBIAN_SSH_IP}"
}

ssh_vm_windows() {
    echo "Ouverture d'une session SSH vers ${VM_WINDOWS_SSH_USER}@${VM_WINDOWS_SSH_IP}"
    ssh "${VM_WINDOWS_SSH_USER}@${VM_WINDOWS_SSH_IP}"
}

#Menu principal avec 'dialog'
while true; do
    choix=$(dialog --checklist "Sélectionnez les actions pour vos machines virtuelles :" 15 60 9 \
        "1" "Démarrer Debian" off \
        "2" "Arrêter Debian" off \
        "3" "Démarrer Windows" off \
        "4" "Arrêter Windows" off \
        "5" "Connexion SSH Debian" off \
        "6" "Connexion SSH Windows" off \
        "7" "Quitter" off 3>&1 1>&2 2>&3)

    clear

    # Vérifier si aucune option n'a été choisie
    if [ -z "$choix" ]; then
        echo "Aucune option sélectionnée. Réessayez."
        continue
    fi

    # Supprimer les guillemets des choix
    choix=$(echo "$choix" | tr -d '"')

    # Traiter chaque choix sélectionné
    for option in $choix; do
        case $option in
            1)
                demarrer_vm "$DEBIAN_VM"
                ;;
            2)
                arreter_vm "$DEBIAN_VM"
                ;;
            3)
                demarrer_vm "$WINDOWS_VM"
                ;;
            4)
                arreter_vm "$WINDOWS_VM"
                ;;
            5)
                ssh_vm_debian
                ;;
            6)
                ssh_vm_windows
                ;;
            7)
                echo "Quitter le script."
                exit 0
                ;;
            *)
                echo "Option invalide : $option"
                ;;
        esac
    done
done

