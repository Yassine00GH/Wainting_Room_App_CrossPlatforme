import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/queue_provider.dart';

void main() {
  test('should add a client to the waiting list', () {
    final manager = QueueProvider();
    manager.addClient('John Doe');

    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'John Doe');
  });

  test('should remove a client from the waiting list', () {
    final manager = QueueProvider();
    manager.addClient('John Doe');
    manager.addClient('Jane Doe');
    manager.removeClient('John Doe');
    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'Jane Doe');
  });

  test('should remove the first client when nextClient() is called', () {
    // ARRANGE
    final manager = QueueProvider();
    manager.addClient('Client A');
    manager.addClient('Client B');

    // ACT
    manager.nextClient();

    // ASSERT
    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'Client B');
  });
}
