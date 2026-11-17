import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/models/sync_status.dart';
import 'package:waiting_room_app/repositories/auth_repository.dart';
import 'package:waiting_room_app/repositories/queue_repository.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';

class _InMemoryFakeStorage extends LocalQueueStorage {
  final List<Map<String, dynamic>> _clients = [];
  final List<Map<String, dynamic>> _users = [
    {
      'id': '00000000-0000-0000-0000-000000000001',
      'nom': 'Admin',
      'prenom': 'Système',
      'email': 'admin@gmail.com',
      'tel': '00000000',
      'mot_de_passe': '123456',
      'role': 'admin',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    }
  ];

  @override
  Future<void> saveClient(Map<String, dynamic> client) async {
    _clients.removeWhere((c) => c['id'] == client['id']);
    _clients.add(Map<String, dynamic>.from(client));
  }

  @override
  Future<List<Map<String, dynamic>>> getClients() async {
    return List<Map<String, dynamic>>.from(_clients);
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingClients() async {
    return _clients
        .where(
            (c) => c['sync_status'] == 'pending' || c['sync_status'] == 'failed')
        .toList();
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    for (final c in _clients) {
      if (c['id'] == id) c['sync_status'] = status.name;
    }
  }

  @override
  Future<void> removeClient(String id) async {
    _clients.removeWhere((c) => c['id'] == id);
  }

  @override
  Future<void> clear() async => _clients.clear();

  @override
  Future<void> saveAuthUser(Map<String, dynamic> user) async {
    _users.removeWhere(
      (u) => u['email'].toString().toLowerCase() ==
          user['email'].toString().toLowerCase(),
    );
    _users.add(Map<String, dynamic>.from(user));
  }

  @override
  Future<Map<String, dynamic>?> getAuthUserByEmail(String email) async {
    final norm = email.trim().toLowerCase();
    for (final u in _users) {
      if (u['email'].toString().toLowerCase() == norm) {
        return Map<String, dynamic>.from(u);
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllAuthUsers() async {
    return List<Map<String, dynamic>>.from(_users);
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
      'Client submits form with Envoyer -> joins queue, then Admin logs in and passes client',
      (WidgetTester tester) async {
    final storage = _InMemoryFakeStorage();
    final authProvider = AuthProvider(AuthRepository(null, storage));
    final queueProvider = QueueProvider(
      repository: QueueRepository(null),
      storage: storage,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<QueueProvider>.value(value: queueProvider),
        ],
        child: const WaitingRoomApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Switch to Client registration tab ("Créer un compte")
    expect(find.text('Créer un compte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('registerTab')));
    await tester.pumpAndSettle();

    // 2. Fill out Nom, Prénom, Email, Téléphone, Mot de passe
    await tester.enterText(find.byKey(const Key('registerNomField')), 'Benali');
    await tester.enterText(
        find.byKey(const Key('registerPrenomField')), 'Sara');
    await tester.enterText(
        find.byKey(const Key('registerEmailField')), 'sara@client.com');
    await tester.enterText(
        find.byKey(const Key('registerTelField')), '55112233');
    await tester.enterText(
        find.byKey(const Key('registerPasswordField')), 'pass1234');

    // 3. Tap "Envoyer"
    final submitBtn = find.byKey(const Key('registerSubmitButton'));
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // 4. Verify client view is shown with ticket & queue position, without Admin button
    expect(find.text('Bonjour, Sara Benali'), findsOneWidget);
    expect(find.text('Position #1 / 1'), findsOneWidget);
    expect(find.byKey(const Key('nextClientButton')), findsNothing);

    // 5. Client logs out
    await tester.tap(find.byKey(const Key('clientLogoutButton')));
    await tester.pumpAndSettle();

    // 6. Admin logs in with admin@gmail.com / 123456
    await tester.enterText(
        find.byKey(const Key('loginEmailField')), 'admin@gmail.com');
    await tester.enterText(
        find.byKey(const Key('loginPasswordField')), '123456');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    // 7. Verify Admin screen sees Sara Benali and can click "Faire passer"
    expect(find.text('Clients in Queue: 1'), findsOneWidget);
    expect(find.text('Sara Benali'), findsOneWidget);
    expect(find.byKey(const Key('nextClientButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nextClientButton')));
    await tester.pumpAndSettle();

    // 8. Queue is now empty after Admin passed the client
    expect(find.text('Clients in Queue: 0'), findsOneWidget);
    expect(find.text('Sara Benali'), findsNothing);
  });
}
