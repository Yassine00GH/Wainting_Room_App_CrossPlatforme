import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waiting_room_app/models/app_connectivity.dart';
import 'package:waiting_room_app/widgets/offline_banner.dart';

void main() {
  testWidgets('Offline banner is displayed when offline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineBanner(status: AppConnectivity.offline),
        ),
      ),
    );
    expect(find.text('No network connection'), findsOneWidget);
  });
}

