import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../helpers/repeater_report.dart';
import '../l10n/l10n.dart';

/// Renders every report found in [text] as a line graph. Tap to toggle the
/// raw text. Falls back to nothing if no report is present (callers should
/// check [RepeaterReport.looksLikeReport] first).
class RepeaterReportView extends StatefulWidget {
  final String text;
  final Color textColor;
  final double textScale;

  const RepeaterReportView({
    super.key,
    required this.text,
    required this.textColor,
    this.textScale = 1.0,
  });

  @override
  State<RepeaterReportView> createState() => _RepeaterReportViewState();
}

class _RepeaterReportViewState extends State<RepeaterReportView> {
  bool _showRaw = false;

  String _title(BuildContext context, RepeaterReportType t) {
    final l10n = context.l10n;
    return switch (t) {
      RepeaterReportType.voltage => l10n.repeaterReport_voltage,
      RepeaterReportType.temperature => l10n.repeaterReport_temperature,
      RepeaterReportType.batteryPercent => l10n.repeaterReport_battery,
    };
  }

  Color _lineColor(BuildContext context, RepeaterReportType t) {
    return switch (t) {
      RepeaterReportType.voltage => Colors.amber.shade700,
      RepeaterReportType.temperature => Colors.deepOrange,
      RepeaterReportType.batteryPercent => Colors.green.shade600,
    };
  }

  @override
  Widget build(BuildContext context) {
    final reports = RepeaterReport.parseAll(widget.text);
    final style = TextStyle(
      color: widget.textColor,
      fontSize: 14 * widget.textScale,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showRaw = !_showRaw),
      child: _showRaw
          ? Text(widget.text, style: style)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in reports) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Text(
                          _title(context, r.type),
                          style: style.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '${r.values.last.toStringAsFixed(r.decimals)}${r.unit}',
                          style: style.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _lineColor(context, r.type),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _ReportChartPainter(
                        report: r,
                        lineColor: _lineColor(context, r.type),
                        textColor: widget.textColor,
                        nowLabel: context.l10n.repeaterReport_now,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
    );
  }
}

class _ReportChartPainter extends CustomPainter {
  final RepeaterReport report;
  final Color lineColor;
  final Color textColor;
  final String nowLabel;

  _ReportChartPainter({
    required this.report,
    required this.lineColor,
    required this.textColor,
    required this.nowLabel,
  });

  TextPainter _tp(String s, {double size = 10, Color? color}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color ?? textColor.withValues(alpha: 0.7),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final v = report.values;
    var lo = report.fixedMin ?? v.reduce(math.min);
    var hi = report.fixedMax ?? v.reduce(math.max);
    if (report.fixedMin == null && report.fixedMax == null) {
      final minPad = report.type == RepeaterReportType.voltage ? 0.02 : 0.5;
      final pad = math.max((hi - lo) * 0.15, minPad);
      lo -= pad;
      hi += pad;
    }
    if (hi - lo < 1e-9) hi = lo + 1;

    const leftPad = 38.0, bottomPad = 16.0, topPad = 6.0, rightPad = 8.0;
    final plot = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    // Horizontal grid + y labels (4 ticks).
    const ticks = 4;
    for (var i = 0; i <= ticks; i++) {
      final f = i / ticks;
      final y = plot.bottom - f * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final label = _tp((lo + f * (hi - lo)).toStringAsFixed(report.decimals));
      label.paint(
        canvas,
        Offset(plot.left - label.width - 4, y - label.height / 2),
      );
    }

    final n = v.length;
    double xAt(int i) => plot.left + (n == 1 ? 0 : i / (n - 1)) * plot.width;
    double yAt(double val) =>
        plot.bottom - ((val - lo) / (hi - lo)) * plot.height;

    // X labels: oldest ("-Nh") and newest ("now"), plus midpoint.
    void xLabel(int i, String s) {
      final t = _tp(s);
      final x = (xAt(i) - t.width / 2).clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(x, plot.bottom + 3));
    }

    xLabel(0, '-${n - 1}h');
    if (n > 6) xLabel((n - 1) ~/ 2, '-${(n - 1) - (n - 1) ~/ 2}h');
    xLabel(n - 1, nowLabel);

    // Filled area + line.
    final line = Path()..moveTo(xAt(0), yAt(v[0]));
    for (var i = 1; i < n; i++) {
      line.lineTo(xAt(i), yAt(v[i]));
    }
    final area = Path.from(line)
      ..lineTo(xAt(n - 1), plot.bottom)
      ..lineTo(xAt(0), plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = lineColor.withValues(alpha: 0.15));
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final dot = Paint()..color = lineColor;
    if (n <= 30) {
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(Offset(xAt(i), yAt(v[i])), 2, dot);
      }
    }
    canvas.drawCircle(Offset(xAt(n - 1), yAt(v[n - 1])), 4, dot);
  }

  @override
  bool shouldRepaint(_ReportChartPainter old) =>
      old.report != report ||
      old.lineColor != lineColor ||
      old.textColor != textColor;
}
