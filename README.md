# 🏨 Waiting Room Pro — Workshop 4 & Workshop 5 (TP4 / TP5)

**Application de Salle d'Attente Offline-First (SQLite), Géolocalisation GPS & Temps Réel Supabase**

- **Étudiant :** Yassine Ghorbel
- **Dépôt GitHub :** [https://github.com/Yassine00GH/Wainting_Room_App_CrossPlatforme](https://github.com/Yassine00GH/Wainting_Room_App_CrossPlatforme)
- **Rapport d'Accompagnement IA :** [`RAPPORT_ACCOMPAGNEMENT_IA_TP5.md`](./RAPPORT_ACCOMPAGNEMENT_IA_TP5.md)

---

## 🎯 Objectifs du Workshop 5 (TP5) — Offline-First & Geolocation
1. **Persistance Locale SQLite (`sqflite`) :** Implémentation de `LocalQueueService` (`waiting_room.db`, table `local_clients`) pour assurer le fonctionnement complet de l'application hors-ligne.
2. **Synchronisation Automatique vers Supabase :** Génération d'identifiants `Uuid().v4()` hors-ligne, suivi par flag `is_synced` (`0` / `1`) et synchronisation non-bloquante (`unawaited(_syncLocalToRemote())`) via `upsert`.
3. **Géolocalisation de l'Appareil (`geolocator`) :** Implémentation de `GeolocationService` avec gestion des permissions Android/iOS et affichage des coordonnées GPS (`📍 lat, lng` à 4 décimales ou `📍 Location not captured`) dans `WaitingRoomScreen`.
4. **Approche TDD & Mocks (`mockito` + `sqflite_common_ffi`) :**
   - Tests unitaires SQLite en mémoire (`test/local_queue_service_test.dart`).
   - Tests unitaires avec `MockGeolocationService` et tests de widgets avec `MockQueueProvider` (`test/queue_provider_geolocation_test.dart`).
   - **15/15 tests automatisés validés au vert**.

---

## 🎯 Objectifs du Workshop 4 (TP4) — Supabase Realtime & Figma UI
1. **Refonte UX/UI Moderne (Figma Style) :** Design soigné avec cartes d'indicateurs (KPIs), champ de saisie pill, badges de position (#1 prioritaire, #2, etc.), avatars avec initiales et dégradé, état vide illustré et barre d'action émeraude fixe.
2. **File Unique (Single Room) :** Gestion centralisée d'une seule file d'attente FIFO (First-In, First-Out).
3. **Backend Temps Réel Supabase :** Flux Postgres Realtime (`.stream(primaryKey: ['id'])`) synchronisé sur tous les appareils connectés.
4. **Sécurité & RLS :** Politiques Row Level Security pour insertion, lecture et suppression anonymes contrôlées.
5. **Gestion des Secrets :** Isolation des clés d'API via `flutter_dotenv` et `.env` (hors versioning Git).

---

## 🛠️ Configuration Supabase

### 1. Schéma de la table `clients` (TP4 + TP5 avec Géolocalisation)
Exécuter la requête suivante dans l'éditeur SQL de Supabase :

```sql
CREATE TABLE clients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);
```

### 2. Politiques de Sécurité RLS (Row Level Security)
Activer RLS et autoriser l'accès pour le rôle anonyme :

```sql
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public insert"
ON clients FOR INSERT TO anon
WITH CHECK (true);

CREATE POLICY "Allow public update"
ON clients FOR UPDATE TO anon
USING (true);

CREATE POLICY "Allow public delete"
ON clients FOR DELETE TO anon
USING (true);

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

### 2. Installation des dépendances & génération des mocks
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 3. Exécution de la suite de tests (15 tests)
```bash
flutter test
```

### 4. Lancement de l'application
```bash
flutter run
```
