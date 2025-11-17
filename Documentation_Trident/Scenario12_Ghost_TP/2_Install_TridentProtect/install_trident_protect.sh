#!/bin/bash

#########################################################################################
# Script d'installation de Trident Protect avec Helm
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Installation de Trident Protect"
echo "#########################################################################################"
echo ""

# Variables par défaut
REGISTRY="${REGISTRY:-registry.demo.netapp.com}"
REGISTRY_USER="${REGISTRY_USER:-registryuser}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-Netapp1!}"
CLUSTER_NAME="${CLUSTER_NAME:-lod1}"
TP_VERSION="${TP_VERSION:-25.10.0}"
HELM_VERSION="${HELM_VERSION:-100.2510.0}"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Vérifier que Trident est installé
echo "1. Vérification de Trident..."
if kubectl get namespace trident &> /dev/null && kubectl get torc trident -n trident &> /dev/null; then
    TRIDENT_STATUS=$(kubectl get torc trident -n trident -o jsonpath='{.status.status}' 2>/dev/null || echo "")
    if [ "$TRIDENT_STATUS" = "Installed" ]; then
        echo -e "${GREEN}✓ Trident est installé${NC}"
    else
        echo -e "${RED}✗ Trident n'est pas en état 'Installed'${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Trident n'est pas installé. Installez Trident d'abord.${NC}"
    exit 1
fi
echo ""

# 2. Créer le namespace
echo "2. Création du namespace trident-protect..."
if kubectl get namespace trident-protect &> /dev/null; then
    echo -e "${YELLOW}⚠ Le namespace 'trident-protect' existe déjà${NC}"
else
    kubectl create namespace trident-protect
    echo -e "${GREEN}✓ Namespace 'trident-protect' créé${NC}"
fi
echo ""

# 3. Créer le secret pour le registry
echo "3. Création du secret pour le registry..."
if kubectl get secret regcred -n trident-protect &> /dev/null; then
    echo -e "${YELLOW}⚠ Le secret 'regcred' existe déjà${NC}"
else
    kubectl create secret docker-registry regcred \
      --docker-username=$REGISTRY_USER \
      --docker-password=$REGISTRY_PASSWORD \
      -n trident-protect \
      --docker-server=$REGISTRY
    echo -e "${GREEN}✓ Secret 'regcred' créé${NC}"
fi
echo ""

# 4. Ajouter le repository Helm
echo "4. Ajout du repository Helm NetApp Trident Protect..."
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/ 2>/dev/null || true
helm repo update netapp-trident-protect
echo -e "${GREEN}✓ Repository Helm ajouté et mis à jour${NC}"
echo ""

# 5. Login au registry
echo "5. Connexion au registry Docker..."
echo "$REGISTRY_PASSWORD" | helm registry login $REGISTRY -u $REGISTRY_USER --password-stdin 2>/dev/null || true
echo -e "${GREEN}✓ Connecté au registry${NC}"
echo ""

# 6. Vérifier si Trident Protect est déjà installé
if helm list -n trident-protect | grep -q trident-protect; then
    echo -e "${YELLOW}⚠ Trident Protect est déjà installé${NC}"
    read -p "Voulez-vous le mettre à jour ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "6. Mise à jour de Trident Protect..."
        helm upgrade trident-protect netapp-trident-protect/trident-protect \
          --set clusterName=$CLUSTER_NAME \
          --version $HELM_VERSION \
          --namespace trident-protect \
          -f trident_protect_helm_values.yaml
        echo -e "${GREEN}✓ Trident Protect mis à jour${NC}"
    else
        echo "Installation annulée."
        exit 0
    fi
else
    # 6. Installer Trident Protect
    echo "6. Installation de Trident Protect..."
    helm install trident-protect netapp-trident-protect/trident-protect \
      --set clusterName=$CLUSTER_NAME \
      --version $HELM_VERSION \
      --namespace trident-protect \
      -f trident_protect_helm_values.yaml
    echo -e "${GREEN}✓ Trident Protect installé${NC}"
fi
echo ""

# 7. Attendre que Trident Protect soit prêt
echo "7. Attente que Trident Protect soit prêt..."
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get pods -n trident-protect -l app=trident-protect-controller-manager --field-selector=status.phase=Running 2>/dev/null | grep -q Running; then
        echo -e "${GREEN}✓ Trident Protect est prêt${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. Vérifiez manuellement l'état de Trident Protect.${NC}"
fi
echo ""

# 8. Installer tridentctl-protect
echo "8. Installation de tridentctl-protect..."
if command -v tridentctl-protect &> /dev/null; then
    CURRENT_VERSION=$(tridentctl-protect version 2>/dev/null || echo "")
    if [ "$CURRENT_VERSION" = "$TP_VERSION" ]; then
        echo -e "${GREEN}✓ tridentctl-protect version $TP_VERSION déjà installé${NC}"
    else
        echo "   Mise à jour de tridentctl-protect vers la version $TP_VERSION..."
        cd
        curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/$TP_VERSION/tridentctl-protect-linux-amd64
        chmod +x tridentctl-protect
        mv ./tridentctl-protect /usr/local/bin
        echo -e "${GREEN}✓ tridentctl-protect installé${NC}"
    fi
else
    echo "   Installation de tridentctl-protect..."
    cd
    curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/$TP_VERSION/tridentctl-protect-linux-amd64
    chmod +x tridentctl-protect
    mv ./tridentctl-protect /usr/local/bin
    echo -e "${GREEN}✓ tridentctl-protect installé${NC}"
fi
echo ""

# 9. Vérifier l'installation
echo "9. Vérification de l'installation..."
echo ""
echo "État des pods Trident Protect :"
kubectl get pods -n trident-protect
echo ""
echo "Version de Trident Protect :"
tridentctl-protect version 2>/dev/null || echo "   (tridentctl-protect non disponible)"
echo ""

# 10. Création de l'AppVault (optionnel)
echo "10. Création de l'AppVault..."
echo ""
read -p "Voulez-vous créer l'AppVault maintenant ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
        echo "   Veuillez fournir les credentials S3 :"
        read -p "   Access Key ID: " S3_ACCESS_KEY
        read -sp "   Secret Access Key: " S3_SECRET_KEY
        echo
    fi
    
    S3_ENDPOINT="${S3_ENDPOINT:-192.168.0.230}"
    S3_BUCKET="${S3_BUCKET:-s3lod}"
    
    read -p "   Endpoint S3 [$S3_ENDPOINT]: " INPUT_ENDPOINT
    S3_ENDPOINT=${INPUT_ENDPOINT:-$S3_ENDPOINT}
    
    read -p "   Bucket name [$S3_BUCKET]: " INPUT_BUCKET
    S3_BUCKET=${INPUT_BUCKET:-$S3_BUCKET}
    
    # Créer le secret S3
    if kubectl get secret s3-creds -n trident-protect &> /dev/null; then
        echo -e "${YELLOW}⚠ Le secret 's3-creds' existe déjà${NC}"
    else
        kubectl create secret generic s3-creds \
          --from-literal=accessKeyID=$S3_ACCESS_KEY \
          --from-literal=secretAccessKey=$S3_SECRET_KEY \
          -n trident-protect
        echo -e "${GREEN}✓ Secret 's3-creds' créé${NC}"
    fi
    
    # Créer l'AppVault
    if tridentctl-protect get appvault ontap-vault -n trident-protect &> /dev/null; then
        echo -e "${YELLOW}⚠ L'AppVault 'ontap-vault' existe déjà${NC}"
    else
        tridentctl-protect create appvault ontap-vault \
          -s s3-creds \
          --bucket $S3_BUCKET \
          --endpoint $S3_ENDPOINT \
          --skip-cert-validation \
          --no-tls \
          -n trident-protect
        echo -e "${GREEN}✓ AppVault 'ontap-vault' créé${NC}"
        
        # Vérifier l'AppVault
        echo ""
        echo "État de l'AppVault :"
        tridentctl-protect get appvault ontap-vault -n trident-protect
    fi
else
    echo "   Création de l'AppVault ignorée. Vous pourrez le créer plus tard."
fi
echo ""

echo "#########################################################################################"
echo -e "${GREEN}✓ Installation de Trident Protect terminée !${NC}"
echo "#########################################################################################"
echo ""
echo "Prochaines étapes :"
echo "  1. Si l'AppVault n'a pas été créé, créez-le avant l'étape 4"
echo "  2. Passer à l'étape suivante : cd ../3_Deploy_Ghost"
echo ""

