import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/queue_provider.dart';

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

  runApp(
    ChangeNotifierProvider(
      create: (context) => QueueProvider(),
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
      home: WaitingRoomScreen(isSupabaseConfigured: isSupabaseConfigured),
    );
  }
}

class WaitingRoomScreen extends StatefulWidget {
  final bool isSupabaseConfigured;
  const WaitingRoomScreen({super.key, this.isSupabaseConfigured = false});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final text = _nameController.text.trim();
    if (text.isNotEmpty) {
      context.read<QueueProvider>().addClient(text);
      _nameController.clear();
      _focusNode.requestFocus();
    }
  }

  bool _isQueueLive(QueueProvider queue) {
    try {
      return queue.isSupabaseConnected;
    } catch (_) {
      return widget.isSupabaseConfigured;
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueProvider>();
    final clients = queue.clients;
    final isLive = _isQueueLive(queue);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Salle d\'Attente',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Offline-First (SQLite) • GPS • Supabase',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Synchroniser avec Supabase',
            icon: const Icon(
              Icons.sync_rounded,
              color: Color(0xFF4F46E5),
              size: 22,
            ),
            onPressed: () => queue.syncNow(),
          ),
          IconButton(
            tooltip: 'GitHub Repository',
            icon: const Icon(
              Icons.code_rounded,
              color: Color(0xFF0F172A),
              size: 22,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.terminal_rounded, color: Color(0xFF4F46E5)),
                      SizedBox(width: 8),
                      Text('Dépôt GitHub'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dépôt officiel du projet (TP4 & TP5) :'),
                      const SizedBox(height: 10),
                      SelectableText(
                        'https://github.com/Yassine00GH/Wainting_Room_App_CrossPlatforme',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            },
          ),
          // Badge indicateur d'état temps réel
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isLive ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isLive ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLive
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isLive ? 'Supabase Live' : 'SQLite Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLive
                        ? const Color(0xFF047857)
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Section Supérieure : Résumé / KPI style Figma
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildMetricsHeader(clients),
            ),

            // Formulaire d'ajout rapide (Pill input moderne)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildInputSection(),
            ),

            // En-tête de la file d'attente
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Clients in Queue: ${clients.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  if (clients.isNotEmpty)
                    Text(
                      'Ordre d\'arrivée (FIFO)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            // Liste des clients ou Empty State
            Expanded(
              child: clients.isEmpty
                  ? _buildEmptyState()
                  : _buildClientsList(queue, clients),
            ),

            // Barre d'action inférieure (Appeler le suivant)
            _buildBottomActionBar(queue, clients),
          ],
        ),
      ),
    );
  }

  /// Carte des métriques d'accueil
  Widget _buildMetricsHeader(List<Map<String, dynamic>> clients) {
    final nextPerson = clients.isNotEmpty ? clients.first.name : 'Aucun';
    final count = clients.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Carte Statistique 1 : Personnes en attente
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF4F46E5),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'En Attente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '$count ${count > 1 ? 'personnes' : 'personne'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 38,
            width: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 16),
          // Carte Statistique 2 : Prochain client
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF10B981),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prochain',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        nextPerson == 'Aucun' ? 'Aucun' : 'Client : $nextPerson',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Champ de saisie style Figma Pill
  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(
            Icons.person_add_alt_1_rounded,
            color: Color(0xFF6366F1),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _nameController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleAddClient(),
              decoration: const InputDecoration(
                hintText: 'Nom du client (ex: Alice Dupont)...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _handleAddClient,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Liste dynamique des clients (avec affichage de la géolocalisation Step 2.3)
  Widget _buildClientsList(
    QueueProvider queue,
    List<Map<String, dynamic>> clients,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final isNext = index == 0;
        final lat = (client['lat'] as num?)?.toDouble();
        final lng = (client['lng'] as num?)?.toDouble();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNext ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
              width: isNext ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isNext ? const Color(0x144F46E5) : const Color(0x06000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar avec dégradé et initiales
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isNext
                          ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                          : [const Color(0xFF64748B), const Color(0xFF94A3B8)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      client.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                // Badge de position (#1, #2...)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isNext
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    client['name']?.toString() ?? 'Anonyme',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (isNext)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Color(0xFFD97706),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Prioritaire',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lat == null
                        ? '📍 Location not captured'
                        : '📍 ${lat.toStringAsFixed(4)}, ${lng?.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Arrivé(e) à ${client.formattedTime}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              tooltip: 'Supprimer ce client',
              onPressed: () => queue.removeClient(client.id),
            ),
          ),
        );
      },
    );
  }

  /// Écran vide style illustration Figma
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E7FF), width: 2),
              ),
              child: const Icon(
                Icons.chair_outlined,
                size: 48,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'La salle d\'attente est vide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tous les clients ont été servis !\nAjoutez un nouveau client ci-dessus pour débuter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre d'action inférieure (Appel du prochain client)
  Widget _buildBottomActionBar(
    QueueProvider queue,
    List<Map<String, dynamic>> clients,
  ) {
    final hasClients = clients.isNotEmpty;
    final nextName = hasClients ? clients.first.name : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('nextClientButton'),
                onPressed: hasClients ? () => queue.nextClient() : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald Green
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: hasClients ? 2 : 0,
                  shadowColor: const Color(0x3310B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      hasClients
                          ? 'Faire passer : $nextName'
                          : 'File d\'attente vide',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
