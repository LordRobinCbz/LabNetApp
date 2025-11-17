#!/bin/bash

#########################################################################################
# Script de déploiement de Ghost avec Trident NFS
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Déploiement de Ghost avec Trident NFS"
echo "#########################################################################################"
echo ""

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Vérifier que Trident est installé
echo "1. Vérification de Trident..."
if kubectl get namespace trident &> /dev/null && kubectl get torc trident -n trident &> /dev/null; then
    echo -e "${GREEN}✓ Trident est installé${NC}"
else
    echo -e "${RED}✗ Trident n'est pas installé. Installez Trident d'abord.${NC}"
    exit 1
fi
echo ""

# 2. Vérifier que la Storage Class existe
echo "2. Vérification de la Storage Class..."
if kubectl get storageclass storage-class-nfs &> /dev/null; then
    echo -e "${GREEN}✓ Storage Class 'storage-class-nfs' existe${NC}"
else
    echo -e "${RED}✗ Storage Class 'storage-class-nfs' n'existe pas. Créez-la d'abord.${NC}"
    exit 1
fi
echo ""

# 3. Vérifier si l'application existe déjà
echo "3. Vérification de l'application existante..."
if kubectl get namespace ghost-tp &> /dev/null; then
    echo -e "${YELLOW}⚠ Le namespace 'ghost-tp' existe déjà${NC}"
    read -p "Voulez-vous supprimer et recréer l'application ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   Suppression de l'application existante..."
        kubectl delete namespace ghost-tp
        echo "   Attente de la suppression..."
        sleep 10
    else
        echo "   Déploiement annulé."
        exit 0
    fi
fi
echo ""

# 4. Déployer l'application
echo "4. Déploiement de Ghost..."
kubectl create -f Ghost/
echo -e "${GREEN}✓ Application déployée${NC}"
echo ""

# 5. Attendre que le PVC soit lié
echo "5. Attente que le PVC soit lié..."
TIMEOUT=120
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    PVC_STATUS=$(kubectl get pvc blog-content -n ghost-tp -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    if [ "$PVC_STATUS" = "Bound" ]; then
        echo -e "${GREEN}✓ PVC lié${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $PVC_STATUS"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${RED}✗ Timeout atteint. Le PVC n'a pas été lié.${NC}"
    kubectl describe pvc blog-content -n ghost-tp
    exit 1
fi
echo ""

# 6. Attendre que le pod soit prêt
echo "6. Attente que le pod soit prêt..."
TIMEOUT=180
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    POD_READY=$(kubectl get pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$POD_READY" = "True" ]; then
        echo -e "${GREEN}✓ Pod prêt${NC}"
        break
    fi
    POD_STATUS=$(kubectl get pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $POD_STATUS"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${RED}✗ Timeout atteint. Le pod n'est pas prêt.${NC}"
    kubectl get pods -n ghost-tp
    kubectl describe pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp
    exit 1
fi
echo ""

# 7. Vérifier le montage du volume
echo "7. Vérification du montage du volume..."
VOLUME_MOUNTED=$(kubectl exec -n ghost-tp $(kubectl get pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp -o name) -- df -h /var/lib/ghost/content 2>/dev/null | grep -c "192.168" || echo "0")
if [ "$VOLUME_MOUNTED" -gt 0 ]; then
    echo -e "${GREEN}✓ Volume NFS monté${NC}"
    kubectl exec -n ghost-tp $(kubectl get pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp -o name) -- df -h /var/lib/ghost/content
else
    echo -e "${YELLOW}⚠ Impossible de vérifier le montage du volume${NC}"
fi
echo ""

# 8. Afficher les informations de l'application
echo "8. Informations de l'application..."
echo ""
echo "État des ressources :"
kubectl get all,pvc -n ghost-tp
echo ""

# Obtenir l'adresse IP d'un nœud
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "N/A")
echo "Accès à l'application :"
echo "  URL: http://$NODE_IP:30080"
echo "  (ou http://<node-ip>:30080 si vous connaissez l'IP d'un nœud)"
echo ""

echo "#########################################################################################"
echo -e "${GREEN}✓ Déploiement de Ghost terminé !${NC}"
echo "#########################################################################################"
echo ""
echo "Prochaines étapes :"
echo "  1. Accéder à Ghost via http://<node-ip>:30080"
echo "  2. Créer un compte administrateur"
echo "  3. Créer un article de test (important pour valider la restauration)"
echo "  4. Passer à l'étape suivante : cd ../4_Protect_Ghost"
echo ""

