#!/bin/bash

#########################################################################################
# Script de vérification des prérequis pour le TP Ghost avec Trident Protect
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Vérification des prérequis"
echo "#########################################################################################"
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Fonction de vérification
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        ERRORS=$((ERRORS + 1))
    fi
}

# 1. Vérifier kubectl
echo "1. Vérification de kubectl..."
if command -v kubectl &> /dev/null; then
    kubectl version --client &> /dev/null
    check "kubectl est installé et fonctionnel"
    kubectl cluster-info &> /dev/null
    check "Cluster Kubernetes accessible"
    kubectl get nodes &> /dev/null
    check "Accès aux nœuds Kubernetes"
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    echo "   → Nombre de nœuds: $NODE_COUNT"
else
    echo -e "${RED}✗${NC} kubectl n'est pas installé"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Vérifier Helm
echo "2. Vérification de Helm..."
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null | head -n1)
    check "Helm est installé (version: $HELM_VERSION)"
else
    echo -e "${RED}✗${NC} Helm n'est pas installé"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 3. Vérifier tridentctl (optionnel, peut ne pas être installé)
echo "3. Vérification de tridentctl..."
if command -v tridentctl &> /dev/null; then
    TRIDENT_VERSION=$(tridentctl version 2>/dev/null | grep "CLIENT VERSION" | awk '{print $3}' || echo "N/A")
    echo -e "${GREEN}✓${NC} tridentctl est installé (version: $TRIDENT_VERSION)"
else
    echo -e "${YELLOW}⚠${NC} tridentctl n'est pas encore installé (sera installé dans l'étape 1)"
fi
echo ""

# 4. Vérifier tridentctl-protect (optionnel, peut ne pas être installé)
echo "4. Vérification de tridentctl-protect..."
if command -v tridentctl-protect &> /dev/null; then
    TP_VERSION=$(tridentctl-protect version 2>/dev/null || echo "N/A")
    echo -e "${GREEN}✓${NC} tridentctl-protect est installé (version: $TP_VERSION)"
else
    echo -e "${YELLOW}⚠${NC} tridentctl-protect n'est pas encore installé (sera installé dans l'étape 2)"
fi
echo ""

# 5. Vérifier les namespaces
echo "5. Vérification des namespaces..."
if kubectl get namespace trident &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Le namespace 'trident' existe déjà"
else
    echo -e "${GREEN}✓${NC} Le namespace 'trident' n'existe pas (sera créé)"
fi

if kubectl get namespace trident-protect &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Le namespace 'trident-protect' existe déjà"
else
    echo -e "${GREEN}✓${NC} Le namespace 'trident-protect' n'existe pas (sera créé)"
fi
echo ""

# 6. Vérifier les variables d'environnement nécessaires
echo "6. Vérification des variables d'environnement..."
if [ -z "$ONTAP_MGMT_LIF" ]; then
    echo -e "${YELLOW}⚠${NC} Variable ONTAP_MGMT_LIF non définie (utilisera les valeurs par défaut)"
else
    echo -e "${GREEN}✓${NC} ONTAP_MGMT_LIF = $ONTAP_MGMT_LIF"
fi

if [ -z "$ONTAP_DATA_LIF" ]; then
    echo -e "${YELLOW}⚠${NC} Variable ONTAP_DATA_LIF non définie (utilisera les valeurs par défaut)"
else
    echo -e "${GREEN}✓${NC} ONTAP_DATA_LIF = $ONTAP_DATA_LIF"
fi

if [ -z "$ONTAP_SVM" ]; then
    echo -e "${YELLOW}⚠${NC} Variable ONTAP_SVM non définie (utilisera les valeurs par défaut)"
else
    echo -e "${GREEN}✓${NC} ONTAP_SVM = $ONTAP_SVM"
fi
echo ""

# 7. Résumé
echo "#########################################################################################"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Tous les prérequis sont satisfaits !${NC}"
    echo ""
    echo "Vous pouvez maintenant passer à l'étape suivante :"
    echo "  cd ../1_Install_Trident"
    exit 0
else
    echo -e "${RED}✗ $ERRORS erreur(s) détectée(s)${NC}"
    echo ""
    echo "Veuillez corriger les erreurs avant de continuer."
    exit 1
fi

