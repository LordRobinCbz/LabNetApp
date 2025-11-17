#!/bin/bash

#########################################################################################
# Script de destruction de l'application Ghost
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Destruction de l'application Ghost"
echo "#########################################################################################"
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="${NAMESPACE:-ghost-tp}"

# 1. Vérifier que l'application existe
echo "1. Vérification de l'application..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' existe${NC}"
else
    echo -e "${YELLOW}⚠ Le namespace '$NAMESPACE' n'existe pas${NC}"
    exit 0
fi
echo ""

# 2. Afficher un avertissement
echo -e "${RED}⚠ ATTENTION : Cette opération va supprimer complètement l'application Ghost !${NC}"
echo -e "${RED}⚠ Toutes les données seront perdues (sauf les backups).${NC}"
echo ""
read -p "Êtes-vous sûr de vouloir continuer ? (yes/N) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Destruction annulée."
    exit 0
fi
echo ""

# 3. Vérifier qu'un backup existe
echo "2. Vérification des backups..."
BACKUP_COUNT=$(tridentctl-protect get backup -n $NAMESPACE 2>/dev/null | grep -c "ghost-backup" || echo "0")
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Backup(s) trouvé(s) ($BACKUP_COUNT)${NC}"
    tridentctl-protect get backup -n $NAMESPACE
else
    echo -e "${YELLOW}⚠ Aucun backup trouvé. Êtes-vous sûr de vouloir continuer ?${NC}"
    read -p "Continuer quand même ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Destruction annulée."
        exit 0
    fi
fi
echo ""

# 4. Afficher les ressources qui seront supprimées
echo "3. Ressources qui seront supprimées :"
kubectl get all,pvc -n $NAMESPACE
echo ""

# 5. Supprimer le Deployment
echo "4. Suppression du Deployment..."
if kubectl get deployment blog -n $NAMESPACE &> /dev/null; then
    kubectl delete deployment blog -n $NAMESPACE
    echo -e "${GREEN}✓ Deployment supprimé${NC}"
else
    echo -e "${YELLOW}⚠ Deployment n'existe pas${NC}"
fi
echo ""

# 6. Supprimer le Service
echo "5. Suppression du Service..."
if kubectl get service blog -n $NAMESPACE &> /dev/null; then
    kubectl delete service blog -n $NAMESPACE
    echo -e "${GREEN}✓ Service supprimé${NC}"
else
    echo -e "${YELLOW}⚠ Service n'existe pas${NC}"
fi
echo ""

# 7. Supprimer les PVC
echo "6. Suppression des PVC (⚠️ cela supprime aussi les données)..."
if kubectl get pvc -n $NAMESPACE &> /dev/null; then
    kubectl delete pvc --all -n $NAMESPACE
    echo -e "${GREEN}✓ PVC supprimés${NC}"
else
    echo -e "${YELLOW}⚠ Aucun PVC trouvé${NC}"
fi
echo ""

# 8. Attendre que les ressources soient supprimées
echo "7. Attente que les ressources soient supprimées..."
sleep 10

# 9. Vérifier que tout est supprimé
echo "8. Vérification de la suppression..."
REMAINING=$(kubectl get all,pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓ Toutes les ressources sont supprimées${NC}"
else
    echo -e "${YELLOW}⚠ Certaines ressources sont encore présentes :${NC}"
    kubectl get all,pvc -n $NAMESPACE
fi
echo ""

# 10. Option : Supprimer le namespace
echo "9. Suppression du namespace (optionnel)..."
read -p "Voulez-vous supprimer le namespace '$NAMESPACE' ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace $NAMESPACE
    echo -e "${GREEN}✓ Namespace supprimé${NC}"
    
    # Attendre que le namespace soit supprimé
    echo "   Attente de la suppression du namespace..."
    TIMEOUT=60
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        if ! kubectl get namespace $NAMESPACE &> /dev/null; then
            echo -e "${GREEN}✓ Namespace supprimé${NC}"
            break
        fi
        echo "   En attente... ($ELAPSED/$TIMEOUT secondes)"
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
else
    echo "   Namespace conservé"
fi
echo ""

echo "#########################################################################################"
echo -e "${GREEN}✓ Destruction de l'application terminée !${NC}"
echo "#########################################################################################"
echo ""
echo "Prochaines étapes :"
echo "  1. Passer à l'étape suivante : cd ../7_Restore_Ghost"
echo ""

