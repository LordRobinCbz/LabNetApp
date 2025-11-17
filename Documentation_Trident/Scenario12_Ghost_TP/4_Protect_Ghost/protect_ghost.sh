#!/bin/bash

#########################################################################################
# Script d'activation de la protection Trident Protect sur Ghost
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Activation de la protection Trident Protect sur Ghost"
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

# 1. Vérifier que Trident Protect est installé
echo "1. Vérification de Trident Protect..."
if kubectl get namespace trident-protect &> /dev/null && kubectl get pods -n trident-protect -l app=trident-protect-controller-manager &> /dev/null; then
    echo -e "${GREEN}✓ Trident Protect est installé${NC}"
else
    echo -e "${RED}✗ Trident Protect n'est pas installé. Installez Trident Protect d'abord.${NC}"
    exit 1
fi
echo ""

# 2. Vérifier que l'AppVault existe
echo "2. Vérification de l'AppVault..."
if tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect &> /dev/null; then
    APPVAULT_STATE=$(tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
    if [ "$APPVAULT_STATE" = "Available" ]; then
        echo -e "${GREEN}✓ AppVault '$APPVAULT_NAME' est disponible${NC}"
    else
        echo -e "${RED}✗ AppVault '$APPVAULT_NAME' n'est pas disponible (état: $APPVAULT_STATE)${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ AppVault '$APPVAULT_NAME' n'existe pas. Créez-le d'abord.${NC}"
    exit 1
fi
echo ""

# 3. Vérifier que l'application Ghost existe
echo "3. Vérification de l'application Ghost..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    if kubectl get deployment blog -n $NAMESPACE &> /dev/null; then
        echo -e "${GREEN}✓ Application Ghost déployée${NC}"
    else
        echo -e "${RED}✗ L'application Ghost n'est pas déployée. Déployez-la d'abord.${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Le namespace '$NAMESPACE' n'existe pas. Déployez Ghost d'abord.${NC}"
    exit 1
fi
echo ""

# 4. Vérifier les labels
echo "4. Vérification des labels..."
LABEL_COUNT=$(kubectl get all,pvc -n $NAMESPACE -l app.kubernetes.io/name=ghost-tp --no-headers 2>/dev/null | wc -l)
if [ "$LABEL_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Labels cohérents trouvés ($LABEL_COUNT ressources)${NC}"
else
    echo -e "${RED}✗ Aucune ressource avec le label 'app.kubernetes.io/name=ghost-tp' trouvée${NC}"
    exit 1
fi
echo ""

# 5. Vérifier si l'Application existe déjà
echo "5. Vérification de l'Application Trident Protect..."
if tridentctl-protect get app $APP_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠ L'Application '$APP_NAME' existe déjà${NC}"
    read -p "Voulez-vous la supprimer et la recréer ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Suppression de l'Application existante..."
        tridentctl-protect delete app $APP_NAME -n $NAMESPACE
        echo "   Attente de la suppression..."
        sleep 5
    else
        echo "   Utilisation de l'Application existante."
        exit 0
    fi
fi
echo ""

# 6. Créer l'Application Trident Protect
echo "6. Création de l'Application Trident Protect..."
tridentctl-protect create app $APP_NAME \
  --namespaces "$NAMESPACE(app.kubernetes.io/name=ghost-tp)" \
  -n $NAMESPACE
echo -e "${GREEN}✓ Application '$APP_NAME' créée${NC}"
echo ""

# 7. Attendre que l'Application soit prête
echo "7. Attente que l'Application soit prête..."
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    APP_STATE=$(tridentctl-protect get app $APP_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "Pending")
    if [ "$APP_STATE" = "Ready" ]; then
        echo -e "${GREEN}✓ Application prête${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $APP_STATE"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. Vérifiez manuellement l'état de l'Application.${NC}"
fi
echo ""

# 8. Afficher l'état de l'Application
echo "8. État de l'Application..."
tridentctl-protect get app $APP_NAME -n $NAMESPACE
echo ""

# 9. Test : Créer un snapshot manuel (optionnel)
echo "9. Test : Création d'un snapshot manuel..."
read -p "Voulez-vous créer un snapshot de test ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SNAPSHOT_NAME="ghost-snap-test-$(date +%s)"
    echo "   Création du snapshot '$SNAPSHOT_NAME'..."
    tridentctl-protect create snapshot $SNAPSHOT_NAME \
      --app $APP_NAME \
      --appvault $APPVAULT_NAME \
      -n $NAMESPACE
    
    echo "   Attente que le snapshot soit complété..."
    sleep 10
    
    echo "   État du snapshot :"
    tridentctl-protect get snap $SNAPSHOT_NAME -n $NAMESPACE 2>/dev/null || echo "   (Snapshot en cours de création...)"
    echo ""
fi

echo "#########################################################################################"
echo -e "${GREEN}✓ Protection de Ghost activée !${NC}"
echo "#########################################################################################"
echo ""
echo "Prochaines étapes :"
echo "  1. Passer à l'étape suivante : cd ../5_Backup_Ghost"
echo ""

