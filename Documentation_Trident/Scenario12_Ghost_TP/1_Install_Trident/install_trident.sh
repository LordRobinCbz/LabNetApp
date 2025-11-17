#!/bin/bash

#########################################################################################
# Script d'installation de Trident 25.10 avec Helm
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Installation de Trident 25.10"
echo "#########################################################################################"
echo ""

# Variables par défaut (peuvent être surchargées par des variables d'environnement)
REGISTRY="${REGISTRY:-registry.demo.netapp.com}"
REGISTRY_USER="${REGISTRY_USER:-registryuser}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-Netapp1!}"
TRIDENT_VERSION="${TRIDENT_VERSION:-25.10.0}"
HELM_VERSION="${HELM_VERSION:-100.2510.0}"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Créer le namespace
echo "1. Création du namespace trident..."
if kubectl get namespace trident &> /dev/null; then
    echo -e "${YELLOW}⚠ Le namespace 'trident' existe déjà${NC}"
else
    kubectl create namespace trident
    echo -e "${GREEN}✓ Namespace 'trident' créé${NC}"
fi
echo ""

# 2. Créer le secret pour le registry
echo "2. Création du secret pour le registry..."
if kubectl get secret regcred -n trident &> /dev/null; then
    echo -e "${YELLOW}⚠ Le secret 'regcred' existe déjà${NC}"
else
    kubectl create secret docker-registry regcred \
      --docker-username=$REGISTRY_USER \
      --docker-password=$REGISTRY_PASSWORD \
      -n trident \
      --docker-server=$REGISTRY
    echo -e "${GREEN}✓ Secret 'regcred' créé${NC}"
fi
echo ""

# 3. Ajouter le repository Helm
echo "3. Ajout du repository Helm NetApp..."
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart/ 2>/dev/null || true
helm repo update netapp-trident
echo -e "${GREEN}✓ Repository Helm ajouté et mis à jour${NC}"
echo ""

# 4. Vérifier si Trident est déjà installé
if helm list -n trident | grep -q trident; then
    echo -e "${YELLOW}⚠ Trident est déjà installé${NC}"
    read -p "Voulez-vous le mettre à jour ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "4. Mise à jour de Trident..."
        helm upgrade trident netapp-trident/trident-operator \
          --version $HELM_VERSION \
          --namespace trident \
          --set tridentAutosupportImage=$REGISTRY/trident-autosupport:$TRIDENT_VERSION \
          --set operatorImage=$REGISTRY/trident-operator:$TRIDENT_VERSION \
          --set tridentImage=$REGISTRY/trident:$TRIDENT_VERSION \
          --set tridentSilenceAutosupport=true \
          --set windows=true \
          --set imagePullSecrets[0]=regcred
        echo -e "${GREEN}✓ Trident mis à jour${NC}"
    else
        echo "Installation annulée."
        exit 0
    fi
else
    # 4. Installer Trident
    echo "4. Installation de Trident..."
    helm install trident netapp-trident/trident-operator \
      --version $HELM_VERSION \
      --namespace trident \
      --set tridentAutosupportImage=$REGISTRY/trident-autosupport:$TRIDENT_VERSION \
      --set operatorImage=$REGISTRY/trident-operator:$TRIDENT_VERSION \
      --set tridentImage=$REGISTRY/trident:$TRIDENT_VERSION \
      --set tridentSilenceAutosupport=true \
      --set windows=true \
      --set imagePullSecrets[0]=regcred
    echo -e "${GREEN}✓ Trident installé${NC}"
fi
echo ""

# 5. Attendre que Trident soit prêt
echo "5. Attente que Trident soit prêt (cela peut prendre quelques minutes)..."
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get torc trident -n trident -o jsonpath='{.status.status}' 2>/dev/null | grep -q "Installed"; then
        echo -e "${GREEN}✓ Trident est prêt${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes)"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. Vérifiez manuellement l'état de Trident.${NC}"
fi
echo ""

# 6. Installer tridentctl (optionnel)
echo "6. Installation de tridentctl..."
if command -v tridentctl &> /dev/null; then
    CURRENT_VERSION=$(tridentctl version 2>/dev/null | grep "CLIENT VERSION" | awk '{print $3}' || echo "")
    if [ "$CURRENT_VERSION" = "$TRIDENT_VERSION" ]; then
        echo -e "${GREEN}✓ tridentctl version $TRIDENT_VERSION déjà installé${NC}"
    else
        echo "   Mise à jour de tridentctl vers la version $TRIDENT_VERSION..."
        cd
        mkdir -p $TRIDENT_VERSION && cd $TRIDENT_VERSION
        wget -q https://github.com/NetApp/trident/releases/download/v$TRIDENT_VERSION/trident-installer-$TRIDENT_VERSION.tar.gz
        tar -xf trident-installer-$TRIDENT_VERSION.tar.gz
        rm -f /usr/local/bin/tridentctl
        ln -sf /root/$TRIDENT_VERSION/trident-installer/tridentctl /usr/local/bin/tridentctl
        echo -e "${GREEN}✓ tridentctl installé${NC}"
    fi
else
    echo "   Installation de tridentctl..."
    cd
    mkdir -p $TRIDENT_VERSION && cd $TRIDENT_VERSION
    wget -q https://github.com/NetApp/trident/releases/download/v$TRIDENT_VERSION/trident-installer-$TRIDENT_VERSION.tar.gz
    tar -xf trident-installer-$TRIDENT_VERSION.tar.gz
    rm -f /usr/local/bin/tridentctl
    ln -sf /root/$TRIDENT_VERSION/trident-installer/tridentctl /usr/local/bin/tridentctl
    echo -e "${GREEN}✓ tridentctl installé${NC}"
fi
echo ""

# 7. Vérifier l'installation
echo "7. Vérification de l'installation..."
echo ""
echo "État des pods Trident :"
kubectl get pods -n trident
echo ""
echo "Version de Trident :"
tridentctl -n trident version 2>/dev/null || echo "   (tridentctl non disponible, vérifiez manuellement)"
echo ""

echo "#########################################################################################"
echo -e "${GREEN}✓ Installation de Trident terminée !${NC}"
echo "#########################################################################################"
echo ""
echo "Prochaines étapes :"
echo "  1. Configurer le backend ONTAP (si pas déjà fait)"
echo "  2. Créer la Storage Class NFS (si pas déjà fait)"
echo "  3. Passer à l'étape suivante : cd ../2_Install_TridentProtect"
echo ""

