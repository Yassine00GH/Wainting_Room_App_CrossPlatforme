# Journal de Bord & Rapport d'Accompagnement IA — TP Waiting Room App (Workshop 5 / TP5)

**Étudiant :** Yassine Ghorbel  
**Projet :** Waiting Room App (Flutter / Dart)  
**TP :** Workshop 5 (TP5) — *Building Offline-First Queue App with Geolocation*  
**Objectif :** Persistance locale SQLite (`sqflite`), synchronisation différée Supabase, géolocalisation GPS (`geolocator`) et tests TDD avec Mocks (`mockito` & `sqflite_common_ffi`)

---

## 1. Ce qu'on devait faire dans ce TP 5

Au Workshop 4, notre application était connectée en temps réel à **Supabase**, mais elle dépendait d'une connexion Internet active pour enregistrer durablement les clients. Dans ce **Workshop 5**, l'objectif était de passer à une véritable architecture **Offline-First** enrichie par la géolocalisation :

- Mettre en place une base de données locale **SQLite** avec [`LocalQueueService`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/local_queue_service.dart) (`sqflite`) pour que l'application fonctionne même en mode avion / sans Wi-Fi.
- Générer des identifiants uniques côté client hors-ligne grâce au package **`uuid`** (`Uuid().v4()`).
- Synchroniser automatiquement les clients non synchronisés (`is_synced = 0`) vers **Supabase** dès que la connexion est disponible via `_syncLocalToRemote()`.
- Capturer la position GPS réelle de chaque client (`lat`, `lng`) via [`GeolocationService`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/geolocation_service.dart) (`geolocator`) et l'afficher dans [`WaitingRoomScreen`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/main.dart).
- Appliquer le **TDD** avec une base SQLite en mémoire (`sqflite_common_ffi`) et des **Mocks** (`mockito` + `build_runner`) pour isoler le GPS et le Provider pendant les tests.

---

## 2. Ma démarche avec l'IA : Pourquoi et comment je l'ai utilisée

Pour ce TP 5 qui combine plusieurs concepts avancés (base locale SQLite, synchronisation cloud Supabase, capteurs matériels GPS et génération de Mocks), j'ai utilisé l'IA comme **tuteur technique et binôme d'architecture** :

- **Pour comprendre l'architecture Offline-First :** Comment éviter les conflits entre la base locale SQLite et la base distante Supabase ? Pourquoi utiliser `upsert` et un booléen/entier `is_synced` ?
- **Pour maîtriser les tests isolés (TDD) :** Comment tester SQLite sur mon PC Windows sans lancer d'émulateur Android, et comment simuler une position GPS fixe dans un test unitaire avec `Mockito` ?
- **Pour diagnostiquer les subtilités de Flutter :** Comprendre le rôle de `unawaited()`, la gestion des permissions Android/iOS et l'initialisation FFI dans les tests.

---

## 3. Nos échanges réels : Prompts & Réponses

Voici les échanges clés qui m'ont permis de comprendre et de construire ce TP 5 étape par étape :

### 💬 Échange 1 : Comprendre le pattern Offline-First (`SQLite` + `Supabase`)

> **👤 Mon prompt :**  
> _"Dans ce TP5, on a à la fois SQLite en local et Supabase dans le cloud. Je ne comprends pas bien pourquoi on écrit d'abord dans SQLite quand on ajoute un client au lieu d'envoyer directement à Supabase et d'utiliser SQLite seulement si Internet est coupé ?"_

> **🤖 Réponse de l'IA :**  
> _"C'est toute la différence entre un simple 'mode secours' et une vraie architecture **Offline-First** !_
> _Si tu essaies d'appeler Supabase en premier quand le réseau est instable (par exemple dans une salle d'attente en sous-sol avec une mauvaise 4G), la requête HTTP peut mettre 10 à 30 secondes avant d'échouer en timeout. Pendant ce temps, l'interface de l'utilisateur fige ou affiche un chargement interminable._
>
> _Avec le pattern **Offline-First** que tu implémentes dans [`QueueProvider`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/queue_provider.dart) :_
> _1. **La source de vérité immédiate est locale :** Tu génères un `Uuid().v4()`, tu enregistres dans SQLite avec `is_synced = 0`, et tu mets à jour l'écran instantanément (en quelques millisecondes)._
> _2. **La synchronisation est asynchrone et non-bloquante :** Tu lances `unawaited(_syncLocalToRemote())`. Si Internet marche, le client est envoyé sur Supabase via `upsert` et marqué `is_synced = 1`. Si Internet est coupé, l'utilisateur ne subit aucun blocage et ses données sont déjà en sécurité sur le disque SQLite !"_

---

### 💬 Échange 2 : Tester SQLite en mémoire avec `sqflite_common_ffi` (TDD)

> **👤 Mon prompt :**  
> _"Quand je lance mon test unitaire `flutter test test/local_queue_service_test.dart` sur Windows, pourquoi on a besoin de `sqflite_common_ffi` et de `inMemory: true` ? Pourquoi `sqflite` normal ne marche pas directement dans `flutter test` ?"_

> **🤖 Réponse de l'IA :**  
> _"Le package `sqflite` classique communique avec le moteur SQLite natif d'Android (Java/Kotlin) ou d'iOS (Swift/Objective-C) via les `MethodChannel` de Flutter. Or, quand tu lances `flutter test`, Flutter n'allume pas d'émulateur Android : il exécute ton code Dart directement sur la machine virtuelle Dart de ton PC Windows !_
>
> _C'est pour ça qu'on utilise deux choses dans [`local_queue_service_test.dart`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/test/local_queue_service_test.dart) :_
> _1. **`sqflite_common_ffi`** : Il utilise `dart:ffi` pour charger la bibliothèque C SQLite directement sur Windows/Mac/Linux sans téléphone._
> _2. **`openDatabase(':memory:')` (`inMemory: true`)** : Au lieu de créer un vrai fichier `.db` sur ton disque dur qui garderait les données d'un test à l'autre, SQLite crée une base ultra-rapide en RAM qui repart à zéro à chaque test :_
>
> ```dart
> setUpAll(() {
>   sqfliteFfiInit();
>   databaseFactory = databaseFactoryFfi;
> });
> ```
> _Résultat : ton test s'exécute en moins d'une seconde et reste 100 % isolé."_

---

### 💬 Échange 3 : Pourquoi stocker `null` au lieu de `(0.0, 0.0)` quand le GPS est refusé ?

> **👤 Mon prompt :**  
> _"Dans [`GeolocationService`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/geolocation_service.dart), si l'utilisateur refuse la permission GPS ou si la localisation est désactivée, la méthode `getCurrentPosition()` renvoie `null`. Pourquoi on ne renvoie pas plutôt `0.0, 0.0` pour éviter d'avoir des `double?` nullables partout ?"_

> **🤖 Réponse de l'IA :**  
> _"C'est une excellente remarque d'ingénierie des données ! En géolocalisation, les coordonnées `(0.0, 0.0)` existent réellement sur Terre : c'est un point précis dans l'océan Atlantique (au large du Ghana), que les développeurs appellent d'ailleurs **'Null Island'** à cause de cette erreur très fréquente._
>
> _Si tu stockes `(0.0, 0.0)` quand le GPS échoue, ta base de données Supabase ne pourra jamais distinguer une vraie coordonnée d'une absence de donnée, et ton interface affichera `📍 0.0000, 0.0000` au lieu d'indiquer honnêtement à l'utilisateur :_
>
> ```dart
> subtitle: Text(
>   lat == null
>       ? '📍 Location not captured'
>       : '📍 ${lat.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)}',
> ),
> ```
> _Utiliser `null` (et des colonnes `REAL` nullables dans SQLite) représente fidèlement la réalité métier."_

---

### 💬 Échange 4 : Mocker le GPS avec `Mockito` et `build_runner`

> **👤 Mon prompt :**  
> _"Dans la Partie 3 du TP, on utilise `@GenerateMocks([GeolocationService])` dans [`queue_provider_geolocation_test.dart`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/test/queue_provider_geolocation_test.dart). Comment ça marche exactement avec `build_runner` et pourquoi on doit injecter `GeolocationService` dans le constructeur de `QueueProvider` ?"_

> **🤖 Réponse de l'IA :**  
> _"Dans un test automatisé, tu ne peux pas dépendre d'une vraie puce GPS ni demander à quelqu'un de cliquer sur 'Autoriser la localisation'. On doit donc remplacer le vrai `GeolocationService` par un **faux service contrôlé (un Mock)**._
>
> _1. **L'injection de dépendances :** Si `QueueProvider` créait lui-même `final _geoService = GeolocationService();` en dur sans paramètre de constructeur, il serait impossible de le remplacer pendant le test. En écrivant :_
> ```dart
> QueueProvider({GeolocationService? geoService})
>     : _geoService = geoService ?? GeolocationService();
> ```
> _ton application utilise le vrai GPS en production, mais ton test peut lui passer `MockGeolocationService()` !_
>
> _2. **Le rôle de `build_runner` :** Quand tu lances `dart run build_runner build`, il lit l'annotation `@GenerateMocks([GeolocationService, QueueProvider])` et génère automatiquement le fichier `queue_provider_geolocation_test.mocks.dart`. Tu peux alors programmer son comportement avec `when(...).thenAnswer(...)` :_
> ```dart
> when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);
> ```
> _C'est ce qui nous permet de vérifier avec certitude que `addClient('Test User')` enregistre bien `lat: 37.7749` et `lng: -122.4194`."_

---

## 4. Ce que j'ai réellement compris et retenu de ce TP 5

1. **L'architecture Offline-First complète :** J'ai compris comment combiner une base locale SQLite ([`LocalQueueService`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/local_queue_service.dart)) pour la réactivité immédiate hors-ligne et une base cloud ([`QueueProvider`](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/queue_provider.dart) + Supabase) pour le partage en temps réel entre appareils.
2. **L'importance des UUID côté client :** Sans connexion à Supabase, le serveur ne peut pas générer l'ID du client. Générer un `Uuid().v4()` dès l'insertion locale permet de faire un `upsert` propre vers Supabase plus tard sans créer de doublons.
3. **La gestion défensive des capteurs matériels :** Un capteur comme le GPS peut être refusé par l'utilisateur, désactivé dans les paramètres Android/iOS ou mettre trop de temps à répondre (`timeLimit`). Le code doit toujours prévoir ces cas sans jamais faire planter l'application.
4. **L'injection de dépendances et le Mocking :** J'ai compris concrètement pourquoi une bonne architecture (Clean Architecture) facilite les tests unitaires et les tests de widgets (`15/15 tests passés`).

---

## 5. Conclusion personnelle

Ce Workshop 5 m'a fait passer d'une application qui fonctionne uniquement dans des conditions idéales (Wi-Fi parfait, permissions toujours acceptées) à une application mobile robuste et réaliste. L'accompagnement par l'IA m'a permis de comprendre en profondeur la mécanique de synchronisation SQLite $\leftrightarrow$ Supabase et l'utilisation professionnelle de `Mockito` et `sqflite_common_ffi` en TDD.
