# Journal de Bord & Rapport d'Apprentissage — TP Waiting Room App (Workshop 3)

**Étudiant :** Yassine Ghorbel  
**Projet :** Waiting Room App (Flutter / Dart)  
**Objectif :** Migration vers `Provider`, méthodologie TDD et tests automatisés

---

## 1. Ce qu'on devait faire dans ce TP

Pour ce Workshop 3, le but était d'améliorer l'application de salle d'attente. Dans les versions précédentes, on gérait tout localement dans la page avec `setState`.

Le travail demandé consistait à :

- Sortir la logique métier de l'interface en utilisant la bibliothèque **Provider** et la classe [ChangeNotifier](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/queue_provider.dart#L3).
- Appliquer rigoureusement la méthode **TDD** (_Test-Driven Development_) : écrire les tests en premier, voir qu'ils échouent, puis coder la solution minimale pour les faire passer.
- Tester à la fois le code Dart pur (tests unitaires) et les composants graphiques (tests de widgets).
- Garder un projet propre validé par l'intégration continue GitHub Actions.

---

## 2. Ma démarche avec l'IA : Pourquoi et comment je l'ai utilisée

Je ne voulais pas demander à l'IA d'écrire tout le projet à ma place : d'une part parce que je n'aurais rien appris, et d'autre part parce que je dois être capable d'expliquer chaque ligne à mon professeur.

J'ai donc utilisé l'IA comme un **tuteur / binôme de code** :

- **Pour comprendre le "pourquoi" :** Pourquoi adopter Provider alors que mon code précédent fonctionnait déjà ?
- **Pour m'aider sur la méthode TDD :** Comment bien découper un test avant même d'avoir créé la fonction ?
- **Pour m'expliquer mes erreurs de compilation et de tests :** Comprendre les messages d'erreur au lieu de tester au hasard jusqu'à ce que ça marche.

---

## 3. Nos échanges réels : Prompts & Réponses

Voici les principaux échanges qui m'ont permis de comprendre et de réaliser ce TP :

### 💬 Échange 1 : Pourquoi passer à Provider ?

> **👤 Mon prompt :**  
> _" Pour ce TP3, le prof nous demande de remplacer notre gestion d'état locale par Provider et ChangeNotifier. Franchement, mon code avec setState marchait déjà bien. C'est quoi le vrai intérêt de faire tout ce détour et de créer une classe à part ?"_

> **🤖 Réponse de l'IA :**  
> _"C'est une très bonne question, et c'est normal de se la poser au début ! Sur une petite page, `setState` semble plus rapide. Mais dès que le projet grossit, ça pose trois gros problèmes :_
> _1. **Mélange des genres :** Tes boutons et ta liste sont mélangés avec la gestion de la file d'attente (ajouter, supprimer, vérifier la taille)._
> _2. **Impossible de tester facilement :** Si tu veux tester que l'ajout d'un client fonctionne, tu es obligé de lancer l'interface graphique Flutter au lieu de faire un test unitaire Dart super rapide._
> _3. **Partage des données :** Si demain tu as un deuxième écran qui veut juste afficher le nombre de personnes qui attendent, avec `setState` tu vas galérer à faire passer la variable._
>
> _Avec **`Provider`** :_
> _- Tu crées une classe Dart pure [QueueProvider](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/queue_provider.dart#L3-L23) qui contient la liste et les fonctions._
> _- Quand la liste change, tu appelles `notifyListeners()`._
> _- Ton écran [WaitingRoomScreen](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/main.dart#L26-L100) devient un simple `StatelessWidget` qui affiche les données et réagit tout seul."_

---

### 💬 Échange 2 : Comment appliquer le TDD sur `nextClient()` ?

> **👤 Mon prompt :**  
> _"Je dois ajouter la méthode `nextClient()` pour faire passer le premier client de la file d'attente. Le prof insiste pour qu'on fasse du TDD. Concrètement, je commence par quoi ? Je fais le test d'abord même si la fonction n'existe pas encore ?"_

> **🤖 Réponse de l'IA :**  
> _"Oui, exactement ! C'est le principe du cycle **Red $\rightarrow$ Green $\rightarrow$ Refactor** :_
>
> _1. **Étape Red :** Tu ouvres [waiting_room_manager_test.dart](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/test/waiting_room_manager_test.dart#L22-L34) et tu écris ce que tu attends :_
>
> ```dart
> test('should remove the first client when nextClient() is called', () {
>   // 1. Arrange : je prépare deux clients
>   final manager = QueueProvider();
>   manager.addClient('Client A');
>   manager.addClient('Client B');
>
>   // 2. Act : j'appelle l'action
>   manager.nextClient();
>
>   // 3. Assert : je vérifie le résultat
>   expect(manager.clients.length, 1);
>   expect(manager.clients.first, 'Client B');
> });
> ```
>
> _Tu lances le test : il échoue en rouge parce que `nextClient()` n'existe pas encore. C'est normal et c'est voulu !_
>
> _2. **Étape Green :** Maintenant, tu vas dans [queue_provider.dart](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/queue_provider.dart#L17-L22) et tu écris le code minimal pour que le test passe :_
>
> ```dart
> void nextClient() {
>   if (_clients.isNotEmpty) {
>     _clients.removeAt(0);
>     notifyListeners();
>   }
> }
> ```
>
> _Tu relances `flutter test` : le test passe au vert._
>
> _3. **Étape Refactor :** Tu vérifies que le code est propre et que tu as bien géré le cas où la liste est vide pour éviter un plantage."_

---

### 💬 Échange 3 : L'erreur avec `context.watch()` dans un bouton

> **👤 Mon prompt :**  
> _"Dans mon fichier [main.dart](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/main.dart), j'ai voulu appeler `context.watch<QueueProvider>().nextClient()` quand l'utilisateur clique sur le bouton, mais Flutter m'affiche un avertissement/erreur. Pourquoi je ne peux pas utiliser watch ici ?"_

> **🤖 Réponse de l'IA :**  
> _"C'est le piège le plus classique avec Provider ! Retiens cette règle simple :_
>
> _- **`context.watch<QueueProvider>()` sert à écouter :** Il dit à Flutter 'Dès que les données changent, redessine ce widget'. Donc on le met uniquement dans la méthode `build()` pour afficher des choses (comme la liste ou le nombre de personnes)._
> _- **`context.read<QueueProvider>()` sert à agir :** Il récupère ton Provider sans s'abonner aux changements. C'est lui qu'il faut utiliser dans les `onPressed` :_
>
> ```dart
> onPressed: () {
>   context.read<QueueProvider>().nextClient();
> }
> ```
>
> _Si tu mets `watch` dans un clic de bouton, Flutter essaie de reconstruire l'écran au milieu d'un événement utilisateur, ce qui crée un conflit."_

---

### 💬 Échange 4 : Résoudre l'erreur `ProviderNotFoundException` en test de widget

> **👤 Mon prompt :**  
> _"J'essaie de tester mon interface dans [waiting_room_widget_test.dart](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/test/waiting_room_widget_test.dart), mais le test plante tout de suite avec `ProviderNotFoundException`. Pourtant dans mon application ça marche bien. Qu'est-ce qui manque ?"_

> **🤖 Réponse de l'IA :**  
> _"Quand tu lances l'application normale, `ChangeNotifierProvider` est tout en haut dans la fonction `main()`. Mais dans un test de widget, Flutter crée un environnement complètement vide et monte uniquement le widget que tu lui donnes._
>
> _Pour corriger ça, tu dois injecter le provider directement dans ton test :_
>
> ```dart
> await tester.pumpWidget(
>   ChangeNotifierProvider(
>     create: (context) => QueueProvider(),
>     child: const WaitingRoomApp(),
>   ),
> );
> ```
>
> _Après avoir tapé du texte ou cliqué sur un bouton, n'oublie pas d'appeler `await tester.pump();` pour que Flutter applique les changements d'état avant de vérifier avec `expect()`."_

---

## 4. Ce que j'ai réellement compris et retenu

Grâce à ces échanges et au travail sur le code :

1. **La séparation des responsabilités :** Mon interface graphique ([main.dart](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/main.dart)) ne s'occupe plus de gérer la liste ; elle ne fait que l'afficher. Toute la logique est centralisée dans [queue_provider.dart](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/lib/queue_provider.dart).
2. **L'intérêt du TDD :** Écrire les tests avant le code oblige à bien penser à ce que la fonction doit faire et aux cas particuliers (ex : que faire si on appelle `nextClient` quand la file est vide ?).
3. **Le réflexe `watch` vs `read` :** `watch` pour afficher les données, `read` pour déclencher les actions dans les boutons.
4. **La fiabilité des tests :** Tous les tests unitaires et widgets passent avec succès (`8/8 tests passés`), et la CI GitHub Actions ([ci.yml](file:///c:/Users/MSI/AndroidStudioProjects/Waiting_room_app/.github/workflows/ci.yml)) valide le projet automatiquement.

---

## 5. Conclusion personnelle

L'utilisation de l'IA comme tuteur m'a permis de ne pas rester bloqué sur des détails de syntaxe ou des erreurs de contexte Flutter, tout en me forçant à comprendre le fonctionnement interne de chaque outil. J'ai compris le sens des choix d'architecture demandés par le professeur au lieu de simplement appliquer une recette sans réfléchir.
