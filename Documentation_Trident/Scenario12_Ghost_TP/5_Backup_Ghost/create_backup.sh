#!/bin/bash

#########################################################################################
# Script de création de snapshot et backup pour Ghost
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Création de snapshot et backup pour Ghost"
echo "#########################################################################################"
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_NAME="${APP_NAME:-ghost-app}"
APPVAULT_NAME="${APPVAULT_NAME:-ontap-vault}"
NAMESPACE="${NAMESPACE:-ghost-tp}"
SNAPSHOT_NAME="${SNAPSHOT_NAME:-ghost-snap1}"
BACKUP_NAME="${BACKUP_NAME:-ghost-backup1}"

# 1. Vérifier que l'Application existe
echo "1. Vérification de l'Application Trident Protect..."
if tridentctl-protect get app $APP_NAME -n $NAMESPACE &> /dev/null; then
    APP_STATE=$(tridentctl-protect get app $APP_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
    if [ "$APP_STATE" = "Ready" ]; then
        echo -e "${GREEN}✓ Application '$APP_NAME' est prête${NC}"
    else
        echo -e "${RED}✗ Application '$APP_NAME' n'est pas prête (état: $APP_STATE)${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Application '$APP_NAME' n'existe pas. Créez-la d'abord.${NC}"
    exit 1
fi
echo ""

# 2. Vérifier que l'AppVault existe
echo "2. Vérification de l'AppVault..."
if tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect &> /dev/null; then
    echo -e "${GREEN}✓ AppVault '$APPVAULT_NAME' existe${NC}"
else
    echo -e "${RED}✗ AppVault '$APPVAULT_NAME' n'existe pas. Créez-le d'abord.${NC}"
    exit 1
fi
echo ""

# 3. Créer un snapshot
echo "3. Création du snapshot '$SNAPSHOT_NAME'..."
if tridentctl-protect get snap $SNAPSHOT_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠ Le snapshot '$SNAPSHOT_NAME' existe déjà${NC}"
    read -p "Voulez-vous le supprimer et en créer un nouveau ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tridentctl-protect delete snap $SNAPSHOT_NAME -n $NAMESPACE
        sleep 5
    else
        echo "   Utilisation du snapshot existant."
    fi
fi

if ! tridentctl-protect get snap $SNAPSHOT_NAME -n $NAMESPACE &> /dev/null; then
    tridentctl-protect create snapshot $SNAPSHOT_NAME \
      --app $APP_NAME \
      --appvault $APPVAULT_NAME \
      -n $NAMESPACE
    echo -e "${GREEN}✓ Snapshot '$SNAPSHOT_NAME' créé${NC}"
else
    echo -e "${GREEN}✓ Snapshot '$SNAPSHOT_NAME' existe déjà${NC}"
fi
echo ""

# 4. Attendre que le snapshot soit complété
echo "4. Attente que le snapshot soit complété..."
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    SNAP_STATE=$(tridentctl-protect get snap $SNAPSHOT_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "Pending")
    if [ "$SNAP_STATE" = "Completed" ]; then
        echo -e "${GREEN}✓ Snapshot complété${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $SNAP_STATE"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. Le snapshot peut encore être en cours.${NC}"
fi
echo ""

# 5. Afficher l'état du snapshot
echo "5. État du snapshot..."
tridentctl-protect get snap $SNAPSHOT_NAME -n $NAMESPACE
echo ""

# 6. Créer un backup
echo "6. Création du backup '$BACKUP_NAME'..."
if tridentctl-protect get backup $BACKUP_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠ Le backup '$BACKUP_NAME' existe déjà${NC}"
    read -p "Voulez-vous le supprimer et en créer un nouveau ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tridentctl-protect delete backup $BACKUP_NAME -n $NAMESPACE
        sleep 5
    else
        echo "   Utilisation du backup existant."
        exit 0
    fi
fi

if ! tridentctl-protect get backup $BACKUP_NAME -n $NAMESPACE &> /dev/null; then
    tridentctl-protect create backup $BACKUP_NAME \
      --app $APP_NAME \
      --snapshot $SNAPSHOT_NAME \
      --appvault $APPVAULT_NAME \
      -n $NAMESPACE
    echo -e "${GREEN}✓ Backup '$BACKUP_NAME' créé${NC}"
    echo ""
    echo -e "${YELLOW}⚠ Le backup peut prendre plusieurs minutes selon la taille des données...${NC}"
else
    echo -e "${GREEN}✓ Backup '$BACKUP_NAME' existe déjà${NC}"
fi
echo ""

# 7. Attendre que le backup soit complété
echo "7. Attente que le backup soit complété (cela peut prendre plusieurs minutes)..."
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    BACKUP_STATE=$(tridentctl-protect get backup $BACKUP_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "Pending")
    if [ "$BACKUP_STATE" = "Completed" ]; then
        echo -e "${GREEN}✓ Backup complété${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $BACKUP_STATE"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. Le backup peut encore être en cours.${NC}"
    echo "   Vous pouvez vérifier l'état avec : tridentctl-protect get backup $BACKUP_NAME -n $NAMESPACE"
fi
echo ""

# 8. Afficher l'état du backup
echo "8. État du backup..."
tridentctl-protect get backup $BACKUP_NAME -n $NAMESPACE
echo ""

# 9. Lister tous les snapshots et backups
echo "9. Résumé des protections..."
echo ""
echo "Snapshots :"
tridentctl-protect get snap -n $NAMESPACE
echo ""
echo "Backups :"
tridentctl-protect get backup -n $NAMESPACE
echo ""

echo "#########################################################################################"
echo -e "${GREEN}✓ Snapshot et backup créés !${NC}"
echo "#########################################################################################"
echo ""
echo "Prochaines étapes :"
echo "  1. Passer à l'étape suivante : cd ../6_Destroy_Ghost"
echo ""

