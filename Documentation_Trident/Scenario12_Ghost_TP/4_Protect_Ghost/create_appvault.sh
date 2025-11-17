#!/bin/bash

#########################################################################################
# Script de création de l'AppVault pour Trident Protect
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Création de l'AppVault pour Trident Protect"
echo "#########################################################################################"
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APPVAULT_NAME="${APPVAULT_NAME:-ontap-vault}"
SECRET_NAME="${SECRET_NAME:-s3-creds}"
S3_ENDPOINT="${S3_ENDPOINT:-192.168.0.230}"
S3_BUCKET="${S3_BUCKET:-s3lod}"

# 1. Vérifier que Trident Protect est installé
echo "1. Vérification de Trident Protect..."
if kubectl get namespace trident-protect &> /dev/null; then
    echo -e "${GREEN}✓ Namespace 'trident-protect' existe${NC}"
else
    echo -e "${RED}✗ Namespace 'trident-protect' n'existe pas. Installez Trident Protect d'abord.${NC}"
    exit 1
fi
echo ""

# 2. Vérifier si l'AppVault existe déjà
echo "2. Vérification de l'AppVault existant..."
if tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect &> /dev/null; then
    APPVAULT_STATE=$(tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect -o jsonpath='{.status.state}' 2>/dev/null || echo "Unknown")
    if [ "$APPVAULT_STATE" = "Available" ]; then
        echo -e "${GREEN}✓ AppVault '$APPVAULT_NAME' existe déjà et est disponible${NC}"
        tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect
        exit 0
    else
        echo -e "${YELLOW}⚠ AppVault '$APPVAULT_NAME' existe mais n'est pas disponible (état: $APPVAULT_STATE)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ AppVault '$APPVAULT_NAME' n'existe pas${NC}"
fi
echo ""

# 3. Demander les credentials S3
echo "3. Configuration des credentials S3..."
if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "   Veuillez fournir les credentials S3 :"
    read -p "   Access Key ID: " S3_ACCESS_KEY
    read -sp "   Secret Access Key: " S3_SECRET_KEY
    echo
fi

if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo -e "${RED}✗ Les credentials S3 sont requis${NC}"
    exit 1
fi

read -p "   Endpoint S3 [$S3_ENDPOINT]: " INPUT_ENDPOINT
S3_ENDPOINT=${INPUT_ENDPOINT:-$S3_ENDPOINT}

read -p "   Bucket name [$S3_BUCKET]: " INPUT_BUCKET
S3_BUCKET=${INPUT_BUCKET:-$S3_BUCKET}
echo ""

# 4. Créer le secret S3
echo "4. Création du secret S3..."
if kubectl get secret $SECRET_NAME -n trident-protect &> /dev/null; then
    echo -e "${YELLOW}⚠ Le secret '$SECRET_NAME' existe déjà${NC}"
    read -p "Voulez-vous le supprimer et le recréer ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret $SECRET_NAME -n trident-protect
    else
        echo "   Utilisation du secret existant."
    fi
fi

if ! kubectl get secret $SECRET_NAME -n trident-protect &> /dev/null; then
    kubectl create secret generic $SECRET_NAME \
      --from-literal=accessKeyID=$S3_ACCESS_KEY \
      --from-literal=secretAccessKey=$S3_SECRET_KEY \
      -n trident-protect
    echo -e "${GREEN}✓ Secret '$SECRET_NAME' créé${NC}"
fi
echo ""

# 5. Créer l'AppVault
echo "5. Création de l'AppVault..."
tridentctl-protect create appvault $APPVAULT_NAME \
  -s $SECRET_NAME \
  --bucket $S3_BUCKET \
  --endpoint $S3_ENDPOINT \
  --skip-cert-validation \
  --no-tls \
  -n trident-protect

echo -e "${GREEN}✓ AppVault '$APPVAULT_NAME' créé${NC}"
echo ""

# 6. Attendre que l'AppVault soit disponible
echo "6. Attente que l'AppVault soit disponible..."
TIMEOUT=60
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    APPVAULT_STATE=$(tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect -o jsonpath='{.status.state}' 2>/dev/null || echo "Pending")
    if [ "$APPVAULT_STATE" = "Available" ]; then
        echo -e "${GREEN}✓ AppVault disponible${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $APPVAULT_STATE"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. Vérifiez manuellement l'état de l'AppVault.${NC}"
fi
echo ""

# 7. Afficher l'état de l'AppVault
echo "7. État de l'AppVault..."
tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect
echo ""

echo "#########################################################################################"
echo -e "${GREEN}✓ AppVault créé avec succès !${NC}"
echo "#########################################################################################"
echo ""

