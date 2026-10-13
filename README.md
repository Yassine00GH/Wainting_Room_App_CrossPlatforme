# 🏨 Waiting Room Pro — Workshop 4 (TP4)

**Application de Salle d'Attente Temps Réel avec Flutter & Supabase**

- **Étudiant :** Yassine Ghorbel
- **Dépôt GitHub :** [https://github.com/Yassine00GH/Wainting_Room_App_CrossPlatforme](https://github.com/Yassine00GH/Wainting_Room_App_CrossPlatforme)
- **Rapport PDF généré :** `RAPPORT_TP4_YASSINE_GHORBEL.pdf`

---

## 🎯 Objectifs du TP4
1. **Refonte UX/UI Moderne (Figma Style) :** Design soigné avec cartes d'indicateurs (KPIs), champ de saisie pill, badges de position (#1 prioritaire, #2, etc.), avatars avec initiales et dégradé, état vide illustré et barre d'action émeraude fixe.
2. **File Unique (Single Room) :** Gestion centralisée d'une seule file d'attente FIFO (First-In, First-Out), sans distribution ou partitionnement multi-rooms.
3. **Backend Temps Réel Supabase :** Remplacement de la gestion d'état locale par un flux Postgres Realtime (`.stream(primaryKey: ['id'])`) synchronisé sur tous les appareils connectés.
4. **Sécurité & RLS :** Politiques Row Level Security pour insertion et suppression anonymes contrôlées.
5. **Gestion des Secrets :** Isolation des clés d'API via `flutter_dotenv` et `.env` (hors versioning Git).

---

## 🛠️ Configuration Supabase

### 1. Schéma de la table `clients`
Exécuter la requête suivante dans l'éditeur SQL de Supabase :

```sql
CREATE TABLE clients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
```

### 2. Politiques de Sécurité RLS (Row Level Security)
Activer RLS et autoriser l'accès pour le rôle anonyme :

```sql
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

-- Autoriser l'insertion publique (entrée dans la file)
CREATE POLICY "Allow public insert"
ON clients FOR INSERT TO anon
WITH CHECK (true);

-- Autoriser la suppression publique (sortie/avancement de file)
CREATE POLICY "Allow public delete"
ON clients FOR DELETE TO anon
USING (true);

-- Autoriser la lecture publique (écoute Realtime)
CREATE POLICY "Allow public select"
ON clients FOR SELECT TO anon
USING (true);
```

---

## 🚀 Démarrage du Projet

### 1. Variables d'environnement
Créez un fichier `.env` à la racine (ou copiez `.env.example`) :

```env
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_ANON_KEY=votre_cle_anon_publique
```

> **Note :** Si les clés ne sont pas renseignées ou en cas d'absence de connexion, l'application bascule automatiquement en **Mode Local / Démo** pour une exécution sans crash.

### 2. Installation des dépendances
```bash
flutter pub get
```

### 3. Exécution des tests
```bash
flutter test
```

### 4. Lancement de l'application
```bash
flutter run
```

---

## 🧪 Validation de la Synchronisation Temps Réel
1. Lancez l'application sur deux terminaux simultanément (ex: deux onglets Chrome, deux émulateurs ou téléphones).
2. Sur **Appareil A** : ajoutez un client *"John"*.
3. Sur **Appareil B** : constatez l'apparition instantanée de *"John"* dans la file sans rechargement.
4. Sur **Appareil B** : cliquez sur *"Faire passer : John"*. *"John"* disparaît instantanément des deux appareils !
