#!/bin/bash

#########################################################################################
# Script all-in-one pour exécuter tout le TP Ghost avec Trident Protect
#########################################################################################

set -e

echo "#########################################################################################"
echo "# TP Complet : Ghost avec Trident et Trident Protect"
echo "#########################################################################################"
echo ""
echo "Ce script exécute toutes les étapes du TP automatiquement :"
echo "  1. Vérification des prérequis"
echo "  2. Installation de Trident"
echo "  3. Installation de Trident Protect"
echo "  4. Déploiement de Ghost"
echo "  5. Activation de la protection"
echo "  6. Création de snapshot et backup"
echo "  7. Destruction de l'application"
echo "  8. Restauration depuis backup"
echo ""
echo -e "\033[1;33m⚠ ATTENTION : Ce script va installer Trident, Trident Protect et déployer Ghost.\033[0m"
echo -e "\033[1;33m⚠ Il va également supprimer et restaurer l'application.\033[0m"
echo ""
read -p "Voulez-vous continuer ? (yes/N) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Exécution annulée."
    exit 0
fi
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

# Fonction pour exécuter une étape
run_step() {
    local step_name=$1
    local step_dir=$2
    local script_name=$3
    
    echo ""
    echo "#########################################################################################"
    echo "# $step_name"
    echo "#########################################################################################"
    echo ""
    
    if [ -f "$SCRIPT_DIR/$step_dir/$script_name" ]; then
        cd "$SCRIPT_DIR/$step_dir"
        if bash "$script_name"; then
            echo -e "${GREEN}✓ $step_name terminé${NC}"
            cd "$SCRIPT_DIR"
            return 0
        else
            echo -e "${RED}✗ $step_name a échoué${NC}"
            cd "$SCRIPT_DIR"
            ERRORS=$((ERRORS + 1))
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Script $script_name non trouvé, étape ignorée${NC}"
        return 0
    fi
}

# Fonction pour exécuter une étape avec confirmation
run_step_with_confirmation() {
    local step_name=$1
    local step_dir=$2
    local script_name=$3
    
    echo ""
    echo "#########################################################################################"
    echo "# $step_name"
    echo "#########################################################################################"
    echo ""
    read -p "Voulez-vous exécuter cette étape ? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}⚠ Étape ignorée${NC}"
        return 0
    fi
    
    run_step "$step_name" "$step_dir" "$script_name"
}

# Étape 0 : Prérequis
run_step "Étape 0 : Vérification des prérequis" "0_Prerequisites" "check_prerequisites.sh"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Les prérequis ne sont pas satisfaits. Veuillez corriger les erreurs.${NC}"
    exit 1
fi

# Étape 1 : Installation de Trident
run_step_with_confirmation "Étape 1 : Installation de Trident" "1_Install_Trident" "install_trident.sh"

# Étape 2 : Installation de Trident Protect
run_step_with_confirmation "Étape 2 : Installation de Trident Protect" "2_Install_TridentProtect" "install_trident_protect.sh"

# Étape 3 : Déploiement de Ghost
run_step_with_confirmation "Étape 3 : Déploiement de Ghost" "3_Deploy_Ghost" "deploy_ghost.sh"

echo ""
echo -e "${YELLOW}⚠ IMPORTANT : Accédez maintenant à Ghost et créez du contenu de test !${NC}"
echo -e "${YELLOW}⚠ Cela est nécessaire pour valider la restauration.${NC}"
echo ""
read -p "Avez-vous créé du contenu de test dans Ghost ? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}⚠ Il est recommandé de créer du contenu avant de continuer.${NC}"
    read -p "Voulez-vous continuer quand même ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exécution interrompue. Reprenez plus tard avec les étapes suivantes."
        exit 0
    fi
fi

# Étape 4 : Activation de la protection
run_step_with_confirmation "Étape 4 : Activation de la protection Trident Protect" "4_Protect_Ghost" "protect_ghost.sh"

# Étape 5 : Création de backup
run_step_with_confirmation "Étape 5 : Création de snapshot et backup" "5_Backup_Ghost" "create_backup.sh"

# Étape 6 : Destruction
echo ""
echo -e "${RED}⚠ ATTENTION : L'étape suivante va supprimer complètement l'application Ghost !${NC}"
echo ""
run_step_with_confirmation "Étape 6 : Destruction de l'application" "6_Destroy_Ghost" "destroy_ghost.sh"

# Étape 7 : Restauration
run_step_with_confirmation "Étape 7 : Restauration depuis backup" "7_Restore_Ghost" "restore_ghost.sh"

# Résumé final
echo ""
echo "#########################################################################################"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ TP terminé avec succès !${NC}"
    echo "#########################################################################################"
    echo ""
    echo "Résumé :"
    echo "  ✓ Trident installé"
    echo "  ✓ Trident Protect installé"
    echo "  ✓ Ghost déployé"
    echo "  ✓ Protection activée"
    echo "  ✓ Backup créé"
    echo "  ✓ Application restaurée"
    echo ""
    echo "Prochaines étapes :"
    echo "  1. Accédez à Ghost : http://<node-ip>:30080"
    echo "  2. Vérifiez que le contenu créé avant la destruction est présent"
    echo "  3. Explorez d'autres fonctionnalités de Trident Protect"
    echo ""
else
    echo -e "${RED}✗ TP terminé avec $ERRORS erreur(s)${NC}"
    echo "#########################################################################################"
    echo ""
    echo "Veuillez vérifier les erreurs ci-dessus et corriger les problèmes."
    echo ""
    exit 1
fi

