/// Parses hourly repeater report messages (battlog / templog / battpct) so
/// they can be rendered as graphs instead of raw text.
///
/// Expected line format (values ordered oldest -> newest):
///   V/h old>new: 4.19 4.18 4.15 ...
///   C/h old>new: 35.5 29.5 28.0 ...
///   %/h old>new: 98 96 99 ...
library;

enum RepeaterReportType { voltage, temperature, batteryPercent }

class RepeaterReport {
  final RepeaterReportType type;

  /// Samples, oldest first, one per hour. The last sample is the most recent.
  final List<double> values;

  const RepeaterReport(this.type, this.values);

  String get unit => switch (type) {
    RepeaterReportType.voltage => 'V',
    RepeaterReportType.temperature => '°C',
    RepeaterReportType.batteryPercent => '%',
  };

  /// Decimal places used when labelling values.
  int get decimals => switch (type) {
    RepeaterReportType.voltage => 2,
    RepeaterReportType.temperature => 1,
    RepeaterReportType.batteryPercent => 0,
  };

  /// Fixed axis bounds where they make sense (null = fit to data).
  double? get fixedMin => type == RepeaterReportType.batteryPercent ? 0 : null;
  double? get fixedMax =>
      type == RepeaterReportType.batteryPercent ? 100 : null;

  static final RegExp _line = RegExp(
    r'(V|C|%)\s*/\s*h\s*old\s*>\s*new\s*:\s*([-+0-9.,\s]+)',
    caseSensitive: false,
  );

  /// Returns every report found in [text] (a message may hold several lines).
  static List<RepeaterReport> parseAll(String text) {
    final reports = <RepeaterReport>[];
    for (final m in _line.allMatches(text)) {
      final type = switch (m.group(1)!.toUpperCase()) {
        'V' => RepeaterReportType.voltage,
        'C' => RepeaterReportType.temperature,
        _ => RepeaterReportType.batteryPercent,
      };
      final values = <double>[];
      for (final token in m.group(2)!.trim().split(RegExp(r'[\s,]+'))) {
        final v = double.tryParse(token);
        if (v != null) values.add(v);
      }
      if (values.length >= 2) reports.add(RepeaterReport(type, values));
    }
    return reports;
  }

  /// True if [text] contains at least one parsable report.
  static bool looksLikeReport(String text) =>
      _line.hasMatch(text) && parseAll(text).isNotEmpty;
}
