# Étape 3 : Déploiement de Ghost

Cette section guide le déploiement de l'application Ghost avec un volume persistant NFS provisionné par Trident.

## Vue d'ensemble

Ghost est une plateforme de publication légère. Nous allons la déployer avec :

- Un namespace dédié (`ghost-tp`)
- Un PVC (PersistentVolumeClaim) utilisant la Storage Class NFS
- Un Deployment Ghost
- Un Service NodePort pour accéder à l'application

## Prérequis

- Trident installé et fonctionnel
- Backend ONTAP-NAS configuré
- Storage Class `storage-class-nfs` créée
- Registry Docker accessible (pour l'image Ghost)

## Déploiement

### Méthode 1 : Script automatique

```bash
cd 3_Deploy_Ghost
./deploy_ghost.sh
```

### Méthode 2 : Déploiement manuel

#### 1. Créer le namespace et déployer l'application

```bash
kubectl create -f Ghost/
```

Cela crée :

- Le namespace `ghost-tp`
- Le PVC `blog-content` (5Gi, NFS)
- Le Deployment `blog`
- Le Service `blog` (NodePort 30080)

#### 2. Vérifier le déploiement

```bash
# Vérifier les ressources créées
kubectl get all,pvc -n ghost-tp

# Résultat attendu :
# NAME                        READY   STATUS    RESTARTS   AGE
# pod/blog-xxxxx-xxxxx         1/1     Running   0          XXs
#
# NAME           TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# service/blog   NodePort   10.xxx.xxx.xxx   <none>        80:30080/TCP   XXs
#
# NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
# persistentvolumeclaim/blog-content Bound    pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx       5Gi        RWX            storage-class-nfs  XXs
```

#### 3. Vérifier le montage du volume

```bash
# Vérifier que le volume est monté
kubectl exec -n ghost-tp $(kubectl get pod -n ghost-tp -o name) -- df -h /var/lib/ghost/content

# Vérifier le contenu du volume
kubectl exec -n ghost-tp $(kubectl get pod -n ghost-tp -o name) -- ls -la /var/lib/ghost/content
```

**Résultat attendu** : Le volume doit être monté depuis une export NFS ONTAP.

## Accès à l'application

Une fois le pod en état `Running`, vous pouvez accéder à Ghost via :

```
http://<node-ip>:30080
```

**Exemple** : `http://192.168.0.63:30080`

### Configuration initiale de Ghost

1. Ouvrez l'URL dans un navigateur
2. Suivez l'assistant de configuration initiale
3. Créez un compte administrateur
4. Créez un premier article de test (important pour valider la restauration plus tard)

## Création de données de test

Il est **important** de créer du contenu dans Ghost avant de faire un backup, pour pouvoir valider la restauration :

1. Connectez-vous à Ghost
2. Créez un article de test avec du contenu unique (ex: "Article de test - TP Trident Protect")
3. Publiez l'article
4. Notez le contenu pour pouvoir le vérifier après la restauration

## Vérification des labels

Les labels sont importants pour Trident Protect. Vérifiez que tous les objets ont le même label :

```bash
# Vérifier les labels
kubectl get all,pvc -n ghost-tp --show-labels

# Tous les objets doivent avoir : app.kubernetes.io/name=ghost-tp
```

## Dépannage

### Le PVC n'est pas lié (Bound)

```bash
# Vérifier les événements
kubectl describe pvc blog-content -n ghost-tp

# Vérifier que la Storage Class existe
kubectl get storageclass storage-class-nfs

# Vérifier que Trident a créé le volume
tridentctl -n trident get volumes
```

### Le pod ne démarre pas

```bash
# Vérifier les logs
kubectl logs -n ghost-tp -l app.kubernetes.io/name=ghost-tp

# Vérifier les événements
kubectl get events -n ghost-tp --sort-by='.lastTimestamp'

# Vérifier que le volume est monté
kubectl describe pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp
```

### L'application n'est pas accessible

```bash
# Vérifier que le service est créé
kubectl get svc -n ghost-tp

# Vérifier que le NodePort est correct
kubectl get svc blog -n ghost-tp -o jsonpath='{.spec.ports[0].nodePort}'

# Tester la connectivité depuis un nœud
curl http://localhost:30080
```

## Prochaines étapes

Une fois Ghost déployé et accessible, et après avoir créé du contenu de test, vous pouvez passer à l'étape suivante :

**[4_Protect_Ghost](../4_Protect_Ghost/)** - Activation de la protection Trident Protect
