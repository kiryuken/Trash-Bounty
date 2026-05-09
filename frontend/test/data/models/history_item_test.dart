import 'package:flutter_test/flutter_test.dart';
import 'package:trash_bounty/data/models/models.dart';

void main() {
  test('HistoryItem.fromJson parses projected history fields', () {
    final item = HistoryItem.fromJson({
      'id': 'bounty-1',
      'type': 'bounty',
      'status': 'completed',
      'location': 'Jalan Mawar',
      'severity': 4,
      'reward': 8.0,
      'points_earned': 80,
      'date': '28 Apr 2026',
      'duration': '15 menit',
      'created_at': '2026-04-28T12:00:00Z',
    });

    expect(item.id, 'bounty-1');
    expect(item.type, 'bounty');
    expect(item.status, 'completed');
    expect(item.location, 'Jalan Mawar');
    expect(item.severity, 4);
    expect(item.reward, 8.0);
    expect(item.pointsEarned, 80);
    expect(item.date, '28 Apr 2026');
    expect(item.duration, '15 menit');
    expect(item.createdAt, '2026-04-28T12:00:00Z');
  });

  test('HistoryItem.fromJson falls back for missing optional fields', () {
    final item = HistoryItem.fromJson({
      'id': 'report-1',
      'status': 'pending',
    });

    expect(item.id, 'report-1');
    expect(item.type, isNull);
    expect(item.location, '');
    expect(item.severity, 0);
    expect(item.reward, 0);
    expect(item.pointsEarned, isNull);
    expect(item.date, isNull);
    expect(item.duration, isNull);
    expect(item.createdAt, isNull);
  });
}