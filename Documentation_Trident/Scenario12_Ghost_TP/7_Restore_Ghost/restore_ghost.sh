#!/bin/bash

#########################################################################################
# Script de restauration de Ghost depuis un backup
#########################################################################################

set -e

echo "#########################################################################################"
echo "# Restauration de Ghost depuis un backup"
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
BACKUP_NAME="${BACKUP_NAME:-ghost-backup1}"
RESTORE_NAME="${RESTORE_NAME:-ghost-restore1}"

# 1. Vérifier que l'AppVault existe
echo "1. Vérification de l'AppVault..."
if tridentctl-protect get appvault $APPVAULT_NAME -n trident-protect &> /dev/null; then
    echo -e "${GREEN}✓ AppVault '$APPVAULT_NAME' existe${NC}"
else
    echo -e "${RED}✗ AppVault '$APPVAULT_NAME' n'existe pas${NC}"
    exit 1
fi
echo ""

# 2. Lister les backups disponibles
echo "2. Liste des backups disponibles..."
echo ""
BACKUP_LIST=$(tridentctl-protect get appvaultcontent $APPVAULT_NAME \
  --show-resources backup \
  --app $APP_NAME \
  -n trident-protect 2>/dev/null || echo "")

if [ -z "$BACKUP_LIST" ] || echo "$BACKUP_LIST" | grep -q "No resources found"; then
    echo -e "${RED}✗ Aucun backup trouvé pour l'application '$APP_NAME'${NC}"
    echo ""
    echo "   Créez un backup d'abord avec :"
    echo "   cd ../5_Backup_Ghost && ./create_backup.sh"
    exit 1
else
    echo "$BACKUP_LIST"
    echo ""
fi

# 3. Vérifier que le backup spécifié existe
echo "3. Vérification du backup '$BACKUP_NAME'..."
BACKUP_EXISTS=$(echo "$BACKUP_LIST" | grep -c "$BACKUP_NAME" || echo "0")
if [ "$BACKUP_EXISTS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Le backup '$BACKUP_NAME' n'a pas été trouvé dans la liste${NC}"
    echo ""
    echo "   Backups disponibles :"
    echo "$BACKUP_LIST" | grep -E "backup|NAME" | head -5
    echo ""
    read -p "Voulez-vous utiliser le premier backup disponible ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_NAME=$(echo "$BACKUP_LIST" | grep "backup" | head -1 | awk '{print $4}' || echo "$BACKUP_NAME")
        echo "   Utilisation du backup : $BACKUP_NAME"
    else
        echo "   Restauration annulée."
        exit 0
    fi
else
    echo -e "${GREEN}✓ Backup '$BACKUP_NAME' trouvé${NC}"
fi
echo ""

# 4. Créer le namespace si nécessaire
echo "4. Vérification du namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' existe${NC}"
    
    # Vérifier s'il y a des ressources existantes
    EXISTING_RESOURCES=$(kubectl get all,pvc -n $NAMESPACE --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$EXISTING_RESOURCES" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Des ressources existent déjà dans le namespace${NC}"
        kubectl get all,pvc -n $NAMESPACE
        echo ""
        read -p "Voulez-vous les supprimer avant de restaurer ? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete all,pvc --all -n $NAMESPACE
            echo "   Ressources supprimées"
        fi
    fi
else
    echo "   Création du namespace '$NAMESPACE'..."
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✓ Namespace créé${NC}"
fi
echo ""

# 5. Vérifier que la Storage Class existe
echo "5. Vérification de la Storage Class..."
if kubectl get storageclass storage-class-nfs &> /dev/null; then
    echo -e "${GREEN}✓ Storage Class 'storage-class-nfs' existe${NC}"
else
    echo -e "${RED}✗ Storage Class 'storage-class-nfs' n'existe pas${NC}"
    echo "   Créez-la d'abord."
    exit 1
fi
echo ""

# 6. Restaurer depuis le backup
echo "6. Restauration depuis le backup '$BACKUP_NAME'..."
if tridentctl-protect get bir $RESTORE_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠ Une restauration '$RESTORE_NAME' existe déjà${NC}"
    read -p "Voulez-vous la supprimer et en créer une nouvelle ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tridentctl-protect delete bir $RESTORE_NAME -n $NAMESPACE
        sleep 5
    else
        echo "   Utilisation de la restauration existante."
    fi
fi

if ! tridentctl-protect get bir $RESTORE_NAME -n $NAMESPACE &> /dev/null; then
    echo "   Création de la restauration..."
    tridentctl-protect create bir $RESTORE_NAME \
      --backup $NAMESPACE/$BACKUP_NAME \
      --appvault $APPVAULT_NAME \
      -n $NAMESPACE \
      --dry-run | kubectl apply -f -
    echo -e "${GREEN}✓ Restauration créée${NC}"
else
    echo -e "${GREEN}✓ Restauration existe déjà${NC}"
fi
echo ""

# 7. Attendre que la restauration soit complétée
echo "7. Attente que la restauration soit complétée (cela peut prendre plusieurs minutes)..."
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    RESTORE_STATE=$(tridentctl-protect get bir $RESTORE_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null || echo "Pending")
    if [ "$RESTORE_STATE" = "Completed" ]; then
        echo -e "${GREEN}✓ Restauration complétée${NC}"
        break
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $RESTORE_STATE"
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠ Timeout atteint. La restauration peut encore être en cours.${NC}"
    echo "   Vous pouvez vérifier l'état avec : tridentctl-protect get bir $RESTORE_NAME -n $NAMESPACE"
fi
echo ""

# 8. Afficher l'état de la restauration
echo "8. État de la restauration..."
tridentctl-protect get bir $RESTORE_NAME -n $NAMESPACE
echo ""

# 9. Attendre que le pod soit prêt
echo "9. Attente que le pod soit prêt..."
TIMEOUT=180
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    POD_READY=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=ghost-tp -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    if [ "$POD_READY" = "True" ]; then
        echo -e "${GREEN}✓ Pod prêt${NC}"
        break
    fi
    POD_STATUS=$(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=ghost-tp -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes) - État: $POD_STATUS"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
echo ""

# 10. Vérifier les ressources restaurées
echo "10. Vérification des ressources restaurées..."
echo ""
kubectl get all,pvc -n $NAMESPACE
echo ""

# 11. Vérifier le montage du volume
echo "11. Vérification du montage du volume..."
VOLUME_MOUNTED=$(kubectl exec -n $NAMESPACE $(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=ghost-tp -o name) -- df -h /var/lib/ghost/content 2>/dev/null | grep -c "192.168" || echo "0")
if [ "$VOLUME_MOUNTED" -gt 0 ]; then
    echo -e "${GREEN}✓ Volume NFS monté${NC}"
    kubectl exec -n $NAMESPACE $(kubectl get pod -n $NAMESPACE -l app.kubernetes.io/name=ghost-tp -o name) -- df -h /var/lib/ghost/content
else
    echo -e "${YELLOW}⚠ Impossible de vérifier le montage du volume${NC}"
fi
echo ""

# 12. Afficher les informations d'accès
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "N/A")
echo "#########################################################################################"
echo -e "${GREEN}✓ Restauration terminée !${NC}"
echo "#########################################################################################"
echo ""
echo "Accès à l'application :"
echo "  URL: http://$NODE_IP:30080"
echo "  (ou http://<node-ip>:30080 si vous connaissez l'IP d'un nœud)"
echo ""
echo "Vérification :"
echo "  1. Accédez à l'URL ci-dessus"
echo "  2. Vérifiez que le contenu créé avant la destruction est présent"
echo "  3. Vérifiez que les articles sont visibles"
echo ""

