import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/helpers/repeater_report.dart';

void main() {
  test('parses voltage report', () {
    const t =
        'V/h old>new: 4.19 4.18 4.15 4.19 4.19 4.16 4.15 4.15 4.15 4.13 4.13 4.11 4.13 4.11 4.10 4.10 4.09 4.08 4.07 4.09 4.08 4.21 4.15 4.21';
    final r = RepeaterReport.parseAll(t);
    expect(r, hasLength(1));
    expect(r.first.type, RepeaterReportType.voltage);
    expect(r.first.values, hasLength(24));
    expect(r.first.values.last, 4.21);
  });

  test('parses temperature and percent', () {
    expect(
      RepeaterReport.parseAll('C/h old>new: 35.5 29.5 28.0').first.type,
      RepeaterReportType.temperature,
    );
    final p = RepeaterReport.parseAll('%/h old>new: 98 96 99 100').first;
    expect(p.type, RepeaterReportType.batteryPercent);
    expect(p.values, [98, 96, 99, 100]);
  });

  test('ignores normal chat', () {
    expect(RepeaterReport.looksLikeReport('hello 4.2V'), isFalse);
  });
}
