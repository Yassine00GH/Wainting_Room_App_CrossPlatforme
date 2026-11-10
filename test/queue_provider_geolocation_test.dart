import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:waiting_room_app/geolocation_service.dart';
import 'package:waiting_room_app/main.dart';
import 'package:waiting_room_app/models/queue_state.dart';
import 'package:waiting_room_app/queue_provider.dart';

import 'queue_provider_geolocation_test.mocks.dart';

@GenerateMocks([GeolocationService, QueueProvider])
void main() {
  test('addClient saves client with geolocation', () async {
    final mockGeo = MockGeolocationService();
    final mockPos = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);

    final provider = QueueProvider(geoService: mockGeo);
    await provider.addClient('Test User');

    final client = provider.clients.last;
    expect(client['lat'], 37.7749);
    expect(client['lng'], -122.4194);
  });

  testWidgets('Displays location when available', (tester) async {
    final provider = MockQueueProvider();
    when(provider.state).thenReturn(QueueState.loaded);
    when(provider.isLoadingMore).thenReturn(false);
    when(provider.clients).thenReturn([
      Client(
        id: '1',
        name: 'Sam',
        lat: 51.5074,
        lng: -0.1278,
        createdAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<QueueProvider>.value(
        value: provider,
        child: const MaterialApp(home: WaitingRoomScreen()),
      ),
    );

    expect(find.text('Sam'), findsOneWidget);
    expect(find.textContaining('51.5074'), findsOneWidget);
  });
}

