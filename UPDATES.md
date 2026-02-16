# Gestion des Mises à Jour PHP

Ce document explique comment les mises à jour de PHP sont gérées dans alpage-php-builds.

## 🤖 Mises à jour automatiques (Recommandé)

### Comment ça marche

1. **Vérification hebdomadaire** (chaque dimanche à 2h)
   - GitHub Actions vérifie php.net pour les nouvelles versions
   - Compare avec nos releases existantes
   - Détecte si PHP 8.4.3 → 8.4.4 par exemple

2. **Build automatique**
   - Si nouvelle version détectée → crée un tag `auto-YYYY.MM.DD`
   - Déclenche le workflow de build
   - Compile toutes les versions PHP (dont la nouvelle)
   - Crée une GitHub Release automatiquement

3. **Alpage récupère automatiquement**
   - Alpage utilise `/releases/latest/download/...`
   - Pointe toujours vers la dernière release
   - Les utilisateurs obtiennent automatiquement la dernière version

### Configuration

C'est déjà configuré ! Les workflows sont dans :
- `.github/workflows/auto-update.yml` - Builds automatiques hebdomadaires
- `.github/workflows/check-php-versions.yml` - Vérification quotidienne (monitoring)

### Désactiver les mises à jour auto

Si tu veux désactiver temporairement :

1. Va sur GitHub → Settings → Actions → General
2. Désactive "Allow all actions and reusable workflows"

Ou commente le `schedule:` dans `auto-update.yml`

## 📋 Vérification manuelle

Pour voir les versions disponibles sans builder :

```bash
# Via GitHub Actions
# → Actions → Check PHP Versions → Run workflow

# Ou localement
for family in 8.1 8.2 8.3 8.4 8.5; do
  curl -s "https://www.php.net/releases/index.php?json&version=$family" | \
  jq -r '.version // "N/A"'
done
```

## 🔨 Build manuel d'une version spécifique

Si tu veux builder une version spécifique immédiatement :

### Option 1 : Via GitHub UI

1. Va sur Actions → Build PHP Binaries
2. Clique "Run workflow"
3. Laisse les versions par défaut ou spécifie (ex: `8.4,8.5`)
4. Clique "Run workflow"

### Option 2 : Via tag Git

```bash
# Créer un tag avec la version PHP
git tag -a v1.1.0 -m "Update to PHP 8.4.4"
git push origin v1.1.0

# Build démarre automatiquement
```

### Option 3 : Localement puis upload manuel

```bash
# Build localement
./scripts/build-php.sh 8.4

# Upload manuellement
gh release create v1.1.0 \
  dist/php-8.4-cli-macos-aarch64.tar.gz \
  dist/php-8.4-fpm-macos-aarch64.tar.gz \
  --notes "Manual build for PHP 8.4.4"
```

## 📊 Scénarios de mise à jour

### Scénario 1 : Patch release (8.4.3 → 8.4.4)

**Automatique :**
- Dimanche prochain → détection automatique
- Build dans 45-60 min
- Nouvelle release créée
- Alpage l'utilise automatiquement

**Manuel (si urgent) :**
```bash
git tag -a patch-8.4.4 -m "Urgent: PHP 8.4.4 security fix"
git push origin patch-8.4.4
```

### Scénario 2 : Minor release (8.6.0 sort)

**Étapes à suivre :**

1. Ajouter 8.6 au config :
   ```bash
   # Éditer build-config/build.json
   "php_versions": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6"]

   # Éditer .github/workflows/build-php.yml
   matrix:
     php: ['8.1', '8.2', '8.3', '8.4', '8.5', '8.6']
   ```

2. Commit et tag :
   ```bash
   git add .
   git commit -m "Add PHP 8.6 support"
   git tag -a v2.0.0 -m "Add PHP 8.6 support"
   git push origin main v2.0.0
   ```

3. Les builds automatiques prendront le relais après

### Scénario 3 : Retirer une version EOL (8.1 devient obsolète)

```bash
# Retirer de build-config/build.json et workflows
# Mais garder les anciennes releases pour les utilisateurs qui en ont encore besoin

git commit -m "Remove PHP 8.1 (End of Life)"
git tag -a v3.0.0 -m "Remove PHP 8.1 support (EOL)"
git push origin main v3.0.0
```

## 🔔 Notifications

### Recevoir des alertes pour nouvelles versions

Tu peux utiliser GitHub Notifications ou configurer un webhook :

1. Settings → Webhooks → Add webhook
2. Payload URL : ton webhook (Slack, Discord, etc.)
3. Events : "Releases"

Ou utilise [GitHub's watch feature](https://docs.github.com/en/account-and-profile/managing-subscriptions-and-notifications-on-github/setting-up-notifications/configuring-notifications#configuring-your-watch-settings-for-an-individual-repository) pour être notifié.

## 🐛 Troubleshooting

### Les builds auto ne se déclenchent pas

Vérifications :
1. GitHub Actions est activé ?
2. Le workflow a les bonnes permissions ?
3. Check les logs dans Actions tab

### Une version spécifique ne build pas

Vérifier dans les logs si :
- La version existe sur php.net
- Les dépendances sont OK
- static-php-cli supporte cette version

### Rollback vers version précédente

```bash
# Lister les releases
gh release list

# Télécharger une ancienne version
gh release download v1.0.0

# Ou pointer Alpage vers un tag spécifique
# dans PhpDownloadService.swift :
private static let alpageBuildsUrl = "https://github.com/USER/alpage-php-builds/releases/download/v1.0.0"
```

## 📅 Planning des mises à jour

### Fréquence recommandée

| Type | Fréquence | Méthode |
|------|-----------|---------|
| Patch (8.4.x) | Hebdomadaire (auto) | Workflow automatique |
| Minor (8.x) | Dès sortie | Manuel + auto après |
| Security fixes | Immédiat | Build manuel |

### Calendrier PHP

Consulte [PHP Release Cycle](https://www.php.net/supported-versions.php) pour :
- Dates de sortie prévues
- Support actif vs sécurité seulement
- End of Life dates

## 💡 Best Practices

1. **Laisse l'auto-update tourner** - C'est gratuit et automatique
2. **Monitor les releases** - Active les notifications GitHub
3. **Teste localement** - Build local avant de pusher si gros changement
4. **Tag sémantiquement** - v1.0.0, v1.1.0, v2.0.0, etc.
5. **Documente** - Note dans release notes si changement important

## 🎯 Résumé

**Tu n'as (presque) rien à faire !**

- ✅ Workflow auto vérifie chaque semaine
- ✅ Build automatique si nouvelle version
- ✅ Release créée automatiquement
- ✅ Alpage utilise toujours la dernière
- ✅ Tu es notifié des nouvelles releases

**Action requise seulement pour :**
- Nouvelle version majeure (8.6, 8.7)
- Retirer version EOL
- Ajouter/retirer extensions
- Problème urgent à résoudre

Simple et efficace ! 🚀
