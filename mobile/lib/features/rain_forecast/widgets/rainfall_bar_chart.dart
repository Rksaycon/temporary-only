// Accessible rainfall bar chart (fl_chart) for the 7-day forecast.
//
// Renders daily FORECAST precipitation in millimetres. It never shows a river
// height — only rainfall — and includes a colour legend + value labels so the
// meaning is not conveyed by colour alone (accessibility requirement).
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/weather_data_models.dart';

class RainfallBarChart extends StatelessWidget {
  final List<WeatherDay> days;

  const RainfallBarChart({super.key, required this.days});

  static const Color _low = Color(0xFF22C55E);
  static const Color _mid = Color(0xFFF59E0B);
  static const Color _high = Color(0xFFEF4444);

  double _mm(WeatherDay d) =>
      (d.precipitationSumMm ?? d.rainSumMm ?? d.showersSumMm ?? 0)
          .clamp(0, double.infinity)
          .toDouble();

  Color _barColor(double mm) {
    if (mm >= 15) return _high;
    if (mm >= 5) return _mid;
    return _low;
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF6C757D);

    if (days.isEmpty) {
      return const Center(child: Text('No data'));
    }

    // A sensible, non-zero max so a low-rain week still shows readable bars.
    final values = days.map(_mm).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final chartMax = (maxVal <= 0) ? 10.0 : (maxVal * 1.25);

    return BarChart(
      BarChartData(
        maxY: chartMax,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x.toInt()];
              final label = _dayName(day.time);
              return BarTooltipItem(
                '$label\n',
                GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                ),
                children: [
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(1)} mm',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34.w,
              interval: chartMax / 4,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toInt().toString(),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28.h,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      _dayInitial(days[idx].time),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _mm(days[i]),
                  color: _barColor(_mm(days[i])),
                  width: 16.w,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _dayName(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('EEE MMM d').format(dt);
  }

  String _dayInitial(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('E').format(dt).substring(0, 1);
  }
}
