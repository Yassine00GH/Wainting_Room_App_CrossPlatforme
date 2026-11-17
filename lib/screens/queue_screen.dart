import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_connectivity.dart';
import '../models/auth_user.dart';
import '../models/queue_state.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/queue_provider.dart';
import '../widgets/client_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/queue_empty_widget.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<QueueProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
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

  Future<void> _showRegisteredAccounts(
      BuildContext context, AuthProvider auth) async {
    await auth.fetchRegisteredUsers();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final users = auth.registeredUsers;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comptes enregistrés (${users.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: users.isEmpty
                    ? const Center(child: Text('Aucun compte trouvé.'))
                    : ListView.builder(
                        controller: controller,
                        itemCount: users.length,
                        itemBuilder: (_, idx) {
                          final u = users[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: u.isAdmin
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFEEF2FF),
                              child: Icon(
                                u.isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: u.isAdmin
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF4F46E5),
                              ),
                            ),
                            title: Text(u.fullName),
                            subtitle: Text('${u.email} • ${u.tel}'),
                            trailing: Chip(
                              label: Text(
                                u.role.name.toUpperCase(),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueProvider>();
    final auth = Provider.of<AuthProvider?>(context);
    final connectivity = Provider.of<ConnectivityProvider?>(context);
    final isOnline = connectivity?.isOnline ?? true;
    final connectivityStatus = connectivity?.status ?? AppConnectivity.online;

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
              child: Icon(
                auth != null
                    ? Icons.admin_panel_settings_rounded
                    : Icons.people_alt_rounded,
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    auth != null
                        ? 'Admin • ${auth.currentUser?.email ?? ''}'
                        : 'Workshop 6 • Resilient Queue',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (auth != null)
            IconButton(
              key: const Key('adminAccountsButton'),
              tooltip: 'Comptes (authentification)',
              icon: const Icon(Icons.group_outlined, color: Color(0xFF4F46E5)),
              onPressed: () => _showRegisteredAccounts(context, auth),
            ),
          IconButton(
            tooltip: 'Synchroniser',
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF4F46E5)),
            onPressed: () => queue.syncPending(),
          ),
          Container(
            margin: EdgeInsets.only(right: auth != null ? 4 : 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFECACA),
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
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOnline
                        ? const Color(0xFF047857)
                        : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          if (auth != null)
            IconButton(
              key: const Key('adminLogoutButton'),
              tooltip: 'Déconnexion',
              icon: const Icon(Icons.logout_rounded, color: Color(0xFF475569)),
              onPressed: () => auth.logout(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau d'état réseau
            OfflineBanner(status: connectivityStatus),

            // Champ d'ajout rapide
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _buildInputSection(),
            ),

            // En-tête de la file
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Clients in Queue: ${queue.clients.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (queue.clients.isNotEmpty)
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

            // Contenu principal selon le QueueState
            Expanded(
              child: _buildQueueContent(queue, auth),
            ),

            // Barre d'action inférieure
            _buildBottomActionBar(queue),
          ],
        ),
      ),
    );
  }

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
                hintText: 'Nom du client (ex: Alice)...',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
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

  Widget _buildQueueContent(QueueProvider queue, AuthProvider? auth) {
    if (queue.state == QueueState.loading && queue.clients.isEmpty) {
      return const LoadingWidget(message: 'Loading waiting queue...');
    }

    if (queue.state == QueueState.empty && queue.clients.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => queue.fetchInitialQueue(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 350,
            child: const QueueEmptyWidget(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => queue.fetchInitialQueue(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: queue.clients.length + (queue.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == queue.clients.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final client = queue.clients[index];
          AuthUser? matchedAccount;
          if (auth != null) {
            for (final u in auth.registeredUsers) {
              if (u.fullName.toLowerCase() ==
                  client.name.trim().toLowerCase()) {
                matchedAccount = u;
                break;
              }
            }
          }
          final contactInfo = matchedAccount != null
              ? '${matchedAccount.email}${matchedAccount.tel.isNotEmpty ? ' • ${matchedAccount.tel}' : ''}'
              : null;

          return ClientCard(
            client: client,
            contactInfo: contactInfo,
            onDelete: () => queue.deleteClient(client.id),
          );
        },
      ),
    );
  }

  Widget _buildBottomActionBar(QueueProvider queue) {
    final hasClients = queue.clients.isNotEmpty;
    final nextName = hasClients ? queue.clients.first.name : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
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
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

