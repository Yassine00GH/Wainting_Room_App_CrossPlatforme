import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/queue_provider.dart';

void main() {
  group('QueueProvider TP4 Tests', () {
    test('addClient should insert a new client with unique id', () async {
      final provider = QueueProvider();
      await provider.addClient('Alice');

      expect(provider.clients.length, 1);
      expect(provider.clients.first.name, 'Alice');
      expect(provider.clients.first.id.isNotEmpty, isTrue);
    });

    test('removeClient should remove the target client', () async {
      final provider = QueueProvider();
      await provider.addClient('Alice');
      final id = provider.clients.first.id;

      await provider.removeClient(id);
      expect(provider.clients.isEmpty, isTrue);
    });

    test('nextClient should advance the queue in FIFO order', () async {
      final provider = QueueProvider();
      await provider.addClient('Client A');
      await provider.addClient('Client B');

      expect(provider.clients.first.name, 'Client A');
      await provider.nextClient();

      expect(provider.clients.length, 1);
      expect(provider.clients.first.name, 'Client B');
    });

    test('clearQueue should empty the waiting list', () async {
      final provider = QueueProvider();
      await provider.addClient('Client 1');
      await provider.addClient('Client 2');
      expect(provider.clients.length, 2);

      await provider.clearQueue();
      expect(provider.clients.isEmpty, isTrue);
    });
  });
}
