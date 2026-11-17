import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_connectivity.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/queue_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/queue_empty_widget.dart';

class ClientQueueScreen extends StatelessWidget {
  const ClientQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final queue = context.watch<QueueProvider>();
    final connectivity = Provider.of<ConnectivityProvider?>(context);
    final isOnline = connectivity?.isOnline ?? true;
    final connectivityStatus = connectivity?.status ?? AppConnectivity.online;

    final user = auth.currentUser;
    final fullName = user?.fullName ?? 'Client';

    final myIndex = queue.clients.indexWhere(
      (c) => c.name.trim().toLowerCase() == fullName.trim().toLowerCase(),
    );
    final Client? myTicket = myIndex != -1 ? queue.clients[myIndex] : null;

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
                Icons.person_rounded,
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
                  Text(
                    'Bonjour, $fullName',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Espace Client • File d\'attente',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
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
          Container(
            margin: const EdgeInsets.only(right: 4),
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
          IconButton(
            key: const Key('clientLogoutButton'),
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF475569)),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            OfflineBanner(status: connectivityStatus),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTicketStatusCard(
                context: context,
                userEmail: user?.email ?? '',
                userTel: user?.tel ?? '',
                fullName: fullName,
                myIndex: myIndex,
                myTicket: myTicket,
                totalCount: queue.clients.length,
                queue: queue,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'File d\'attente en direct (${queue.clients.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Lecture seule',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _buildReadOnlyList(queue, fullName),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketStatusCard({
    required BuildContext context,
    required String userEmail,
    required String userTel,
    required String fullName,
    required int myIndex,
    required Client? myTicket,
    required int totalCount,
    required QueueProvider queue,
  }) {
    final inQueue = myTicket != null;
    final isNext = myIndex == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNext
              ? const [Color(0xFF059669), Color(0xFF10B981)]
              : const [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x264F46E5),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  inQueue
                      ? (isNext ? 'C\'est votre tour !' : 'En attente')
                      : 'Hors de la file',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (inQueue)
                Text(
                  'Position #${myIndex + 1} / $totalCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$userEmail${userTel.isNotEmpty ? ' • $userTel' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          if (!inQueue)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('clientJoinQueueButton'),
                onPressed: () => queue.addClient(fullName),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Rejoindre la file d\'attente'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    isNext
                        ? 'Veuillez vous présenter au guichet.'
                        : 'L\'administrateur vous fera passer bientôt.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('clientLeaveQueueButton'),
                  onPressed: () => queue.deleteClient(myTicket.id),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Quitter',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyList(QueueProvider queue, String myName) {
    if (queue.state == QueueState.loading && queue.clients.isEmpty) {
      return const LoadingWidget(message: 'Chargement de la file...');
    }

    if (queue.clients.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => queue.fetchInitialQueue(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const SizedBox(
            height: 280,
            child: QueueEmptyWidget(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => queue.fetchInitialQueue(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: queue.clients.length,
        itemBuilder: (context, index) {
          final client = queue.clients[index];
          final isMe =
              client.name.trim().toLowerCase() == myName.trim().toLowerCase();

          return Card(
            elevation: isMe ? 2 : 0.5,
            color: isMe ? const Color(0xFFEEF2FF) : Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isMe ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isMe
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFF1F5F9),
                foregroundColor: isMe
                    ? Colors.white
                    : const Color(0xFF475569),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      client.name,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isMe)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Vous',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text('Arrivée à ${client.formattedTime}'),
            ),
          );
        },
      ),
    );
  }
}
