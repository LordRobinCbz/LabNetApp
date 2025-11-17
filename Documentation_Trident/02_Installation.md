# Comment installer le provisionneur Trident

## Prérequis

Avant d'installer Trident, assurez-vous d'avoir :

- Un cluster Kubernetes ou OpenShift fonctionnel (version 1.17+ recommandée)
- Un backend de stockage NetApp ONTAP configuré et accessible
- Les credentials nécessaires pour accéder au backend ONTAP
- Un namespace dédié pour Trident (généralement `trident`)
- Les droits d'administration sur le cluster Kubernetes

## Méthodes d'installation

Trident peut être installé de plusieurs façons, selon vos besoins et votre environnement :

### 1. Installation avec Helm (Recommandé)

Helm est la méthode la plus simple et la plus courante pour installer Trident.

#### Étapes d'installation

```bash
# 1. Ajouter le repository Helm NetApp
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart/
helm repo update

# 2. Créer le namespace
kubectl create namespace trident

# 3. Installer Trident avec Helm
helm install trident netapp-trident/trident-operator \
  --namespace trident \
  --version 100.2510.0
```

#### Configuration avancée avec Helm

Vous pouvez personnaliser l'installation avec un fichier `values.yaml` :

```yaml
# values.yaml
tridentImage: registry.example.com/trident:25.10.0
autosupportImage: registry.example.com/trident-autosupport:25.10.0
silenceAutosupport: true
windows: true
imagePullSecrets:
  - regcred
```

Puis installer avec :

```bash
helm install trident netapp-trident/trident-operator \
  --namespace trident \
  -f values.yaml
```

#### Mise à jour avec Helm

```bash
# Mettre à jour le repository
helm repo update netapp-trident

# Upgrader Trident
helm upgrade trident netapp-trident/trident-operator \
  --namespace trident \
  --version 100.2510.0
```

### 2. Installation avec l'Operator (Méthode manuelle)

Cette méthode offre plus de contrôle sur la configuration.

#### Étapes d'installation

```bash
# 1. Télécharger Trident
cd
mkdir 25.10.0 && cd 25.10.0
wget https://github.com/NetApp/trident/releases/download/v25.10.0/trident-installer-25.10.0.tar.gz
tar -xf trident-installer-25.10.0.tar.gz

# 2. Modifier les images si nécessaire (registry privé)
sed -i s,netapp/,registry.example.com/, ~/25.10.0/trident-installer/deploy/bundle.yaml

# 3. Créer le namespace et le secret pour le registry
kubectl create namespace trident
kubectl create secret docker-registry regcred \
  --docker-username=user \
  --docker-password=password \
  -n trident \
  --docker-server=registry.example.com

# 4. Installer l'Operator
kubectl create -f ~/25.10.0/trident-installer/deploy/bundle.yaml

# 5. Créer le TridentOrchestrator
cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentOrchestrator
metadata:
  name: trident
spec:
  debug: true
  namespace: trident
  tridentImage: registry.example.com/trident:25.10.0
  autosupportImage: registry.example.com/trident-autosupport:25.10.0
  silenceAutosupport: true
  windows: true
  imagePullSecrets:
  - regcred
EOF
```

### 3. Installation avec tridentctl (Méthode legacy)

Cette méthode est dépréciée mais peut être utile pour des configurations très spécifiques.

```bash
# 1. Télécharger et installer tridentctl
wget https://github.com/NetApp/trident/releases/download/v25.10.0/trident-installer-25.10.0.tar.gz
tar -xf trident-installer-25.10.0.tar.gz
cd trident-installer

# 2. Installer Trident
./tridentctl install -n trident
```

### 4. Installation avec GitOps (ArgoCD)

Pour les environnements GitOps, vous pouvez utiliser ArgoCD pour déployer Trident.

Voir le [Scenario18](../../Kubernetes_v6/Trident_Scenarios/Scenario18) pour plus de détails.

## Vérification de l'installation

Après l'installation, vérifiez que Trident fonctionne correctement :

```bash
# Vérifier les pods
kubectl get pods -n trident

# Vérifier la version
tridentctl -n trident version

# Vérifier le statut de l'orchestrator
kubectl get torc -n trident
kubectl describe torc trident -n trident
```

Vous devriez voir :

- `trident-controller-*` : Pod du contrôleur principal
- `trident-node-*` : DaemonSets sur chaque nœud
- `trident-operator-*` : Pod de l'operator (si installé avec Operator)

## Configuration post-installation

### Télécharger tridentctl

Pour gérer Trident depuis la ligne de commande :

```bash
cd
mkdir 25.10.0 && cd 25.10.0
wget https://github.com/NetApp/trident/releases/download/v25.10.0/trident-installer-25.10.0.tar.gz
tar -xf trident-installer-25.10.0.tar.gz
rm -f /usr/bin/tridentctl
ln -sf /root/25.10.0/trident-installer/tridentctl /usr/local/bin/tridentctl
```

### Activer l'autocomplétion

```bash
mkdir -p ~/.bash/completions
tridentctl completion bash > ~/.bash/completions/tridentctl-completion.bash
source ~/.bash/completions/tridentctl-completion.bash
echo 'source ~/.bash/completions/tridentctl-completion.bash' >> ~/.bashrc
```

## Prérequis pour CSI Topology

Si vous prévoyez d'utiliser CSI Topology (pour la localisation des volumes), configurez les labels sur les nœuds **avant** l'installation de Trident :

```bash
# Label "REGION"
kubectl label node node1 "topology.kubernetes.io/region=west" --overwrite
kubectl label node node2 "topology.kubernetes.io/region=west" --overwrite
kubectl label node node3 "topology.kubernetes.io/region=east" --overwrite

# Label "ZONE"
kubectl label node node1 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node node2 "topology.kubernetes.io/zone=west1" --overwrite
kubectl label node node3 "topology.kubernetes.io/zone=east1" --overwrite
```

## Dépannage

### Problèmes courants

1. **Pods en état Pending** : Vérifiez les ressources disponibles et les imagePullSecrets
2. **Erreurs de connexion au backend** : Vérifiez la connectivité réseau et les credentials
3. **Problèmes de permissions** : Vérifiez les ClusterRoles et ClusterRoleBindings

### Commandes utiles

```bash
# Logs du contrôleur
kubectl logs -n trident -l app=trident-controller

# Logs des nœuds
kubectl logs -n trident -l app=trident-node

# Événements
kubectl get events -n trident --sort-by='.lastTimestamp'
```

## Prochaines étapes

Une fois Trident installé, vous devez :

1. **Créer des backends** : Configurer la connexion à vos systèmes de stockage ONTAP
2. **Créer des Storage Classes** : Définir les types de stockage disponibles pour les applications
3. **Tester le provisionnement** : Créer un PVC de test pour valider l'installation

Voir [03_Utilisation.md](03_Utilisation.md) pour la suite.
