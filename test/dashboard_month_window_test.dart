import 'package:flutter_test/flutter_test.dart';
import 'package:rokter_badhon/services/dashboard_service.dart';

void main() {
  test('Dhaka calendar month starts and ends at 18:00 UTC', () {
    final before = DhakaMonthWindow.containing(DateTime.utc(2026, 9, 30, 17, 59));
    expect(before.startUtc, DateTime.utc(2026, 8, 31, 18));
    expect(before.endUtc, DateTime.utc(2026, 9, 30, 18));

    final after = DhakaMonthWindow.containing(DateTime.utc(2026, 9, 30, 18));
    expect(after.startUtc, DateTime.utc(2026, 9, 30, 18));
    expect(after.endUtc, DateTime.utc(2026, 10, 31, 18));
  });

  test('December to January rollover preserves the exclusive upper bound', () {
    final december = DhakaMonthWindow.containing(
      DateTime.utc(2026, 12, 31, 17, 59),
    );
    expect(december.startUtc, DateTime.utc(2026, 11, 30, 18));
    expect(december.endUtc, DateTime.utc(2026, 12, 31, 18));

    final january = DhakaMonthWindow.containing(
      DateTime.utc(2026, 12, 31, 18),
    );
    expect(january.startUtc, december.endUtc);
    expect(january.endUtc, DateTime.utc(2027, 1, 31, 18));
  });

  test('leap-year February includes Bangladesh February 29', () {
    final february = DhakaMonthWindow.containing(
      DateTime.utc(2024, 2, 29, 17, 59),
    );
    expect(february.startUtc, DateTime.utc(2024, 1, 31, 18));
    expect(february.endUtc, DateTime.utc(2024, 2, 29, 18));

    final march = DhakaMonthWindow.containing(
      DateTime.utc(2024, 2, 29, 18),
    );
    expect(march.startUtc, february.endUtc);
  });
}
