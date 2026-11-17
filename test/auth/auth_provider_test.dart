import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/models/auth_user.dart';
import 'package:waiting_room_app/providers/auth_provider.dart';
import 'package:waiting_room_app/repositories/auth_repository.dart';
import 'package:waiting_room_app/storage/local_queue_storage.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuthProvider & Authentification Table Tests', () {
    late LocalQueueStorage storage;
    late AuthRepository repository;
    late AuthProvider authProvider;

    setUp(() {
      storage = LocalQueueStorage(inMemory: true);
      repository = AuthRepository(null, storage);
      authProvider = AuthProvider(repository);
    });

    tearDown(() async {
      await storage.close();
    });

    test('Admin login with admin@gmail.com / 123456 succeeds with admin role',
        () async {
      final ok = await authProvider.login('admin@gmail.com', '123456');

      expect(ok, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.isAdmin, isTrue);
      expect(authProvider.isClient, isFalse);
      expect(authProvider.currentUser?.role, UserRole.admin);
      expect(authProvider.currentUser?.email, 'admin@gmail.com');
    });

    test('Admin login fails with wrong password', () async {
      final ok = await authProvider.login('admin@gmail.com', 'wrongpass');

      expect(ok, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, isNotNull);
    });

    test('Client registration stores unique email and assigns client role',
        () async {
      final user = await authProvider.registerClient(
        nom: 'Ghorbel',
        prenom: 'Yassine',
        email: 'Yassine@Test.com',
        tel: '22334455',
        password: 'secret123',
      );

      expect(user, isNotNull);
      expect(user!.role, UserRole.client);
      expect(user.email, 'yassine@test.com');
      expect(user.fullName, 'Yassine Ghorbel');
      expect(authProvider.isClient, isTrue);
      expect(authProvider.isAdmin, isFalse);
    });

    test('Duplicate email registration is rejected (unique per email)',
        () async {
      final first = await authProvider.registerClient(
        nom: 'Benali',
        prenom: 'Sara',
        email: 'sara@example.com',
        tel: '55112233',
        password: 'password1',
      );
      expect(first, isNotNull);

      authProvider.logout();

      final duplicate = await authProvider.registerClient(
        nom: 'Autre',
        prenom: 'Sara',
        email: 'SARA@example.com',
        tel: '99887766',
        password: 'password2',
      );

      expect(duplicate, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('existe déjà'));
    });

    test('Client can log out and log back in with registered credentials',
        () async {
      await authProvider.registerClient(
        nom: 'Ali',
        prenom: 'Karim',
        email: 'karim@example.com',
        tel: '12345678',
        password: 'mypassword',
      );
      authProvider.logout();
      expect(authProvider.isAuthenticated, isFalse);

      final loggedIn =
          await authProvider.login('karim@example.com', 'mypassword');
      expect(loggedIn, isTrue);
      expect(authProvider.isClient, isTrue);
      expect(authProvider.currentUser?.fullName, 'Karim Ali');
    });
  });
}
