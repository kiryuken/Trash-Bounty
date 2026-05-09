import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:trash_bounty/core/providers/auth_provider.dart';
import 'package:trash_bounty/data/models/models.dart';
import 'package:trash_bounty/features/history/history_page.dart';

void main() {
  testWidgets('HistoryPage shows earnings only for allowed statuses', (tester) async {
    final container = ProviderContainer(
      overrides: [
        historyProvider.overrideWith((ref) async => const [
              HistoryItem(
                id: 'report-1',
                type: 'report',
                status: 'bounty_created',
                location: 'Jalan Melati',
                severity: 0,
                reward: 11,
                pointsEarned: 111,
                date: '29 Apr 2026',
                createdAt: '2026-04-29T10:00:00Z',
              ),
              HistoryItem(
                id: 'bounty-1',
                type: 'bounty',
                status: 'completed',
                location: 'Jalan Mawar',
                severity: 4,
                reward: 8,
                pointsEarned: 80,
                date: '28 Apr 2026',
                duration: '15 menit',
                createdAt: '2026-04-28T12:00:00Z',
              ),
              HistoryItem(
                id: 'report-2',
                type: 'report',
                status: 'rejected',
                location: 'Jalan Kenanga',
                severity: 3,
                reward: 99,
                pointsEarned: 999,
                date: '27 Apr 2026',
                createdAt: '2026-04-27T08:00:00Z',
              ),
            ]),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider.notifier).setUser(
          const UserModel(
            id: 'user-1',
            name: 'Reporter',
            email: 'reporter@example.com',
            role: 'reporter',
            points: 0,
            walletBalance: 0,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: HistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Laporan yang telah Anda buat'), findsOneWidget);
    expect(find.text('Bounty Dibuat'), findsOneWidget);
    expect(find.text('Selesai'), findsNWidgets(2));
    expect(find.text('Ditolak'), findsOneWidget);

    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('191'), findsOneWidget);
    expect(find.text(currency.format(19)), findsOneWidget);

    expect(find.text('+111 poin'), findsOneWidget);
    expect(find.text('+80 poin'), findsOneWidget);
    expect(find.text('+999 poin'), findsNothing);
    expect(find.text(currency.format(99)), findsNothing);
  });

  testWidgets('HistoryPage shows executor copy for executor role', (tester) async {
    final container = ProviderContainer(
      overrides: [
        historyProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    container.read(authProvider.notifier).setUser(
          const UserModel(
            id: 'user-2',
            name: 'Executor',
            email: 'executor@example.com',
            role: 'executor',
            points: 0,
            walletBalance: 0,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: HistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bounty yang telah Anda kerjakan'), findsOneWidget);
    expect(find.text('Belum ada riwayat'), findsOneWidget);
  });
}