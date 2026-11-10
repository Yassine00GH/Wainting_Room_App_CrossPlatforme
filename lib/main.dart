import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/connectivity_provider.dart';
import 'providers/queue_provider.dart';
import 'repositories/queue_repository.dart';
import 'screens/queue_screen.dart';
import 'services/connectivity_service.dart';
import 'services/geolocation_service.dart';
import 'services/sync_service.dart';
import 'storage/local_queue_storage.dart';

export 'screens/queue_screen.dart';
export 'providers/queue_provider.dart';

typedef WaitingRoomScreen = QueueScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chargement sécurisé du fichier .env
  bool isSupabaseConfigured = false;
  try {
    await dotenv.load(fileName: '.env');
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl != null &&
        supabaseAnonKey != null &&
        supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('your-project-id') &&
        !supabaseUrl.contains('xyzcompanyproject')) {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      isSupabaseConfigured = true;
    }
  } catch (e) {
    debugPrint('Supabase initialization skipped: $e');
  }

  final supabaseClient =
      isSupabaseConfigured ? Supabase.instance.client : null;

  // Initialisation des couches de l'architecture
  final connectivityService = ConnectivityService(supabaseClient);
  final connectivityProvider =
      ConnectivityProvider(connectivityService)..initialize();

  final geolocationService = GeolocationService();
  final storage = LocalQueueStorage();
  final repository = QueueRepository(supabaseClient);
  final syncService = SyncService(storage, repository);

  final queueProvider = QueueProvider(
    repository: repository,
    geolocationService: geolocationService,
    storage: storage,
    syncService: syncService,
  )..fetchInitialQueue();

  // Écoute des événements Realtime
  repository.subscribeToInserts(queueProvider.handleRealtimeInsert);
  repository.subscribeToDeletes(queueProvider.handleRealtimeDelete);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connectivityProvider),
        ChangeNotifierProvider.value(value: queueProvider),
      ],
      child: WaitingRoomApp(isSupabaseConfigured: isSupabaseConfigured),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  final bool isSupabaseConfigured;
  const WaitingRoomApp({super.key, this.isSupabaseConfigured = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo
          brightness: Brightness.light,
          primary: const Color(0xFF4F46E5),
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
      ),
      home: const QueueScreen(),
    );
  }
}
