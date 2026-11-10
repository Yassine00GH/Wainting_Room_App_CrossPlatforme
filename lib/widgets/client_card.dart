import 'package:flutter/material.dart';
import '../models/client.dart';

class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onDelete;

  const ClientCard({
    super.key,
    required this.client,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          client.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          client.hasLocation
              ? 'Location available (${client.locationText})'
              : 'Location not captured',
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEEF2FF),
          foregroundColor: const Color(0xFF4F46E5),
          child: Text(
            client.initials,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              client.hasLocation ? Icons.location_on : Icons.location_off,
              color: client.hasLocation ? Colors.green : Colors.grey,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

