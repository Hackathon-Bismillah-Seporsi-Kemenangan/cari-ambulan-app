import 'package:cari_ambulan/core/network/api_client.dart';
import 'package:cari_ambulan/core/widgets/pill_bottom_nav.dart';
import 'package:cari_ambulan/features/driver/data/mock_driver_repository.dart';
import 'package:cari_ambulan/features/driver/domain/driver_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  Future<void> pumpDriver(
    WidgetTester tester, {
    MockDriverRepository? repo,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(driverRepository: repo));
    await tester.pump(); // resolve the signed-in session
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PillBottomNav),
        matching: find.text(label),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Riwayat lists finished trips', (tester) async {
    await pumpDriver(tester);
    await openTab(tester, 'Riwayat');

    expect(find.text('Order yang sudah Anda tangani'), findsOneWidget);
    expect(find.text('Kecelakaan · #CA-MOCK01'), findsOneWidget);
    expect(find.text('Andi Pratama'), findsOneWidget);
    expect(find.textContaining('RSUD Dr. Soebandi · Diserahkan'), findsOne);
    expect(find.text('Sesak Nafas · #CA-MOCK02'), findsOneWidget);
    expect(
      find.textContaining('Pasien sudah dibawa keluarga'),
      findsOneWidget,
    );
    // One of each, in the summary and on the cards.
    expect(find.text('Selesai'), findsNWidgets(2));
    expect(find.text('Dibatalkan'), findsNWidgets(2));

    await unmount(tester);
  });

  testWidgets('Riwayat says so when the server has no history yet', (
    tester,
  ) async {
    await pumpDriver(tester, repo: _NoHistoryRepository());
    await openTab(tester, 'Riwayat');

    expect(find.text('Riwayat belum tersedia di server.'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Profil shows the ambulance and trip counts', (tester) async {
    await pumpDriver(tester);
    await openTab(tester, 'Profil');

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('B 1199 SGM'), findsOneWidget);
    expect(find.text('Ambulans ALS'), findsOneWidget);
    expect(find.text('SIM-31750001'), findsOneWidget);
    expect(find.text('RSUD Dr. Soebandi'), findsOneWidget);
    expect(find.text('Trip hari ini'), findsOneWidget);
    expect(find.text('124'), findsOneWidget); // total completed

    await unmount(tester);
  });

  testWidgets('Keluar asks before signing out', (tester) async {
    await pumpDriver(tester);
    await openTab(tester, 'Profil');

    await tester.tap(find.text('Keluar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Keluar dari akun?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Keluar dari akun?'), findsNothing);
    expect(find.text('Budi Santoso'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Keluar').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Budi Santoso'), findsNothing);

    await unmount(tester);
  });

  testWidgets('the driver can change their name and phone', (tester) async {
    final repo = MockDriverRepository();
    await pumpDriver(tester, repo: repo);
    await openTab(tester, 'Profil');

    await tester.tap(find.byTooltip('Ubah profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // slide in
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama lengkap'),
      'Budi S.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nomor telepon'),
      '081200009999',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pump(const Duration(seconds: 1)); // save
    await tester.pump(const Duration(seconds: 1)); // close the sheet

    expect(find.text('Ubah profil'), findsNothing);
    expect(find.text('Budi S.'), findsOneWidget);
    expect(find.text('081200009999'), findsOneWidget);

    await unmount(tester);
  });
}

class _NoHistoryRepository extends MockDriverRepository {
  @override
  Future<List<DriverTripHistoryItem>> fetchTripHistory() async =>
      throw const ApiException('Not Found', statusCode: 404);
}
