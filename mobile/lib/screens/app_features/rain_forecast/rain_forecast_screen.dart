// Rain Forecast & 7-Day Water-Level / Flood-Risk Outlook screen.
//
// Design contract (see features/rain_forecast/models/weather_risk_models.dart):
//  - RAINFALL (mm) + probability come from Open-Meteo and are always labeled
//    as forecast values.
//  - RIVER WATER LEVEL (m) is a separate product. When no verified gauge feed
//    exists for the location, this screen shows an honest "unavailable" state
//    and NEVER substitutes rainfall for a river height.
//  - Risk labels follow documented rules in features/rain_forecast/risk.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../features/rain_forecast/aggregation/forecast_summary.dart';
import '../../../features/rain_forecast/models/weather_data_models.dart';
import '../../../features/rain_forecast/risk/rain_risk_classifier.dart';

import '../../../features/rain_forecast/widgets/rainfall_bar_chart.dart';
import '../../../features/rain_forecast/widgets/weather_code_map.dart';
import '../../../providers/rain_forecast_provider.dart';
import '../../../theme/app_theme.dart';

/// Local palette - delegates to AppColors (single source of truth) so a brand
/// restyle repaints this screen with no edits here.
class _RFColors {
  static const Color safe = Color(0xFF22C55E);
  static const Color alert = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.deepAnchor, AppColors.heritagePurple],
      );
}

class RainForecastScreen extends ConsumerStatefulWidget {
  const RainForecastScreen({super.key});

  @override
  ConsumerState<RainForecastScreen> createState() => _RainForecastScreenState();
}

class _RainForecastScreenState extends ConsumerState<RainForecastScreen> {
  int _selectedDayIndex = 0;

  AppColorScheme get _colors => AppColors.of(context);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scaffoldBg =>
      _isDark ? AppColors.dark.background : AppColors.warmHearth;
  Color get _cardBg =>
      _isDark ? AppColors.dark.cardSurface : AppColors.cardWhite;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rainForecastProvider);

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(state),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.heritagePurple,
                onRefresh: () =>
                    ref.read(rainForecastProvider.notifier).refresh(),
                child: _buildBody(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER
  Widget _buildHeader(RainForecastState state) {
    final lastUpdated = state.lastUpdated;
    final updatedText = lastUpdated == null
        ? 'Updating...'
        : 'Updated ${DateFormat('MMM d, h:mm a').format(lastUpdated)}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 16.w, 18.h),
      decoration: BoxDecoration(gradient: _RFColors.headerGradient),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rain Forecast',
                  style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '7-Day Rainfall & Flood Risk Outlook',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.place_rounded,
                        size: 14.sp, color: Colors.white70),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        state.location.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13.sp, color: Colors.white70),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        updatedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (state.isStale) _staleChip(),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _headerRefreshButton(state),
        ],
      ),
    );
  }

  Widget _staleChip() {
    return Container(
      margin: EdgeInsets.only(left: 6.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 11.sp, color: Colors.white),
          SizedBox(width: 3.w),
          Text(
            'Cached',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRefreshButton(RainForecastState state) {
    final refreshing = state.isRefreshing;
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Refresh',
        onPressed: refreshing
            ? null
            : () => ref.read(rainForecastProvider.notifier).refresh(),
        icon: refreshing
            ? SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  // BODY DISPATCH (loading / error / offline / stale / loaded)
  Widget _buildBody(RainForecastState state) {
    if (!state.hasData &&
        (state.status == RainForecastStatus.initial ||
            state.status == RainForecastStatus.loading)) {
      return _buildLoadingState();
    }
    if (!state.hasData && state.status == RainForecastStatus.error) {
      return _buildErrorState(state.message ??
          'Unable to load the forecast right now. Please try again.');
    }
    if (!state.hasData && state.status == RainForecastStatus.offline) {
      return _buildErrorState(
        state.message ??
            'No internet connection and no saved forecast is available yet.',
        isOffline: true,
      );
    }
    final data = state.data;
    if (data == null) {
      return _buildErrorState('No forecast data available.');
    }

    final banner = _statusBanner(state);

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (banner != null) ...[banner, SizedBox(height: 12.h)],
        _buildCurrentConditionsCard(data),
        SizedBox(height: 16.h),
        _buildRiskCard(data),
        SizedBox(height: 16.h),
        _buildRainfallChartCard(data),
        SizedBox(height: 16.h),
        _buildSevenDaySection(data),
        SizedBox(height: 16.h),
        _buildHourlyDetailCard(data),
        SizedBox(height: 16.h),
        _buildWeeklySummaryCard(data),
        SizedBox(height: 16.h),
        _buildWaterLevelCard(state),
        SizedBox(height: 16.h),
        _buildSafetyGuidanceCard(data),
        SizedBox(height: 16.h),
        _buildAttributionCard(),
      ],
    );
  }

  Widget? _statusBanner(RainForecastState state) {
    if (state.message == null) return null;
    final isOffline = state.isOffline;
    final accent = isOffline ? _RFColors.alert : _RFColors.danger;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isOffline ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
              size: 18.sp, color: accent),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              state.message!,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                height: 1.45,
                color: _colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 80.h),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.heritagePurple),
              SizedBox(height: 16.h),
              Text(
                'Loading 7-day forecast...',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: _colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message, {bool isOffline = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(24.w),
      children: [
        SizedBox(height: 60.h),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.error_outline_rounded,
                size: 56.sp,
                color: _colors.textMuted,
              ),
              SizedBox(height: 16.h),
              Text(
                isOffline ? 'You are offline' : 'Forecast unavailable',
                style: GoogleFonts.poppins(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: _colors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  height: 1.5,
                  color: _colors.textSecondary,
                ),
              ),
              SizedBox(height: 24.h),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.heritagePurple,
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                ),
                onPressed: () =>
                    ref.read(rainForecastProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // CURRENT CONDITIONS CARD
  Widget _buildCurrentConditionsCard(WeatherForecastData data) {
    final current = data.current;
    final today = data.daily.isNotEmpty ? data.daily.first : null;
    final descriptor = describeWeatherCode(current?.weatherCode);

    final tempText = current?.temperatureC != null
        ? '${current!.temperatureC!.round()}C'
        : '--';
    final precipToday = today == null
        ? null
        : (today.precipitationSumMm ?? today.rainSumMm ?? today.showersSumMm);
    final probToday = today?.precipitationProbabilityMaxPct;

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Current Conditions', Icons.thermostat_rounded),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(descriptor.icon, size: 52.sp, color: AppColors.riverFlow),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tempText,
                      style: GoogleFonts.poppins(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w700,
                        color: _colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      descriptor.description,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: _colors.textSecondary,
                      ),
                    ),
                    if (current?.relativeHumidityPct != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Humidity ${current!.relativeHumidityPct!.round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: _colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _infoRow(
            'Today expected rainfall',
            precipToday == null
                ? 'No data'
                : '${precipToday.toStringAsFixed(1)} mm',
          ),
          _infoRow(
            'Today max rain probability',
            probToday == null ? 'No data' : '$probToday%',
          ),
          SizedBox(height: 8.h),
          Text(
            'These are FORECAST values for today from the weather model, '
            'not live on-the-ground measurements.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              height: 1.45,
              color: _colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // RISK CARD (rain-only outlook; documented rules)
  Widget _buildRiskCard(WeatherForecastData data) {
    final rule = RainRiskClassifier.classifyRainOutlook(
      daily: data.daily,
      location: data.location,
    );
    final accent = _riskAccent(rule.label);

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Rainfall Outlook', Icons.shield_moon_outlined),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(_riskIcon(rule.label), color: accent, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.label,
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Based on forecast rain probability only.',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: _colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'This label reflects the rainfall forecast, not an official flood '
            'warning. Always follow advisories from PAGASA and your local MDRRMO.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              height: 1.45,
              color: _colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Color _riskAccent(String label) {
    final l = label.toLowerCase();
    if (l.contains('high') || l.contains('heavy')) return _RFColors.danger;
    if (l.contains('moderate') || l.contains('isolated')) {
      return _RFColors.alert;
    }
    if (l.contains('no measurable') || l.contains('unavailable')) {
      return _colors.textMuted;
    }
    return _RFColors.safe;
  }

  IconData _riskIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('high') || l.contains('heavy')) {
      return Icons.warning_amber_rounded;
    }
    if (l.contains('moderate') || l.contains('isolated')) {
      return Icons.info_outline_rounded;
    }
    if (l.contains('no measurable') || l.contains('unavailable')) {
      return Icons.do_not_disturb_alt_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  // RAINFALL CHART CARD (fl_chart)
  Widget _buildRainfallChartCard(WeatherForecastData data) {
    final days = data.daily;
    if (days.isEmpty) {
      return _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Expected Rainfall', Icons.bar_chart_rounded),
            SizedBox(height: 12.h),
            _emptyInline('No rainfall data available.'),
          ],
        ),
      );
    }

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
              'Expected Rainfall (next 7 days)', Icons.bar_chart_rounded),
          SizedBox(height: 6.h),
          Text(
            'Daily forecast precipitation in millimetres (mm).',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: _colors.textMuted,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 190.h,
            child: RainfallBarChart(days: days),
          ),
          SizedBox(height: 10.h),
          _chartLegend(),
        ],
      ),
    );
  }

  Widget _chartLegend() {
    return Row(
      children: [
        _legendDot(_RFColors.safe, '0-5 mm'),
        SizedBox(width: 12.w),
        _legendDot(_RFColors.alert, '5-15 mm'),
        SizedBox(width: 12.w),
        _legendDot(_RFColors.danger, '>15 mm'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            color: _colors.textMuted,
          ),
        ),
      ],
    );
  }

  // SEVEN-DAY FORECAST (selectable)
  Widget _buildSevenDaySection(WeatherForecastData data) {
    final days = data.daily;
    if (days.isEmpty) {
      return _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('7-Day Forecast', Icons.calendar_month_rounded),
            SizedBox(height: 12.h),
            _emptyInline('No daily forecast available.'),
          ],
        ),
      );
    }

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('7-Day Forecast', Icons.calendar_month_rounded),
          SizedBox(height: 4.h),
          Text(
            'Tap a day to see its hourly rainfall detail.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: _colors.textMuted,
            ),
          ),
          SizedBox(height: 12.h),
          ...List.generate(days.length, (index) {
            final day = days[index];
            final selected = index == _selectedDayIndex;
            return _dayRow(day, index, selected);
          }),
        ],
      ),
    );
  }

  Widget _dayRow(WeatherDay day, int index, bool selected) {
    final descriptor = describeWeatherCode(day.weatherCode);
    final precip = day.precipitationSumMm ?? day.rainSumMm ?? day.showersSumMm;
    final date = _parseDate(day.time);
    final accent = AppColors.heritagePurple;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => setState(() => _selectedDayIndex = index),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color:
                selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.4) : _colors.border,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayLabel(date, index),
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: _colors.textPrimary,
                      ),
                    ),
                    Text(
                      date == null ? '--' : DateFormat('MMM d').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: _colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(descriptor.icon, size: 22.sp, color: AppColors.riverFlow),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${_tempText(day)}  -  '
                  '${precip == null ? '--' : '${precip.toStringAsFixed(1)} mm'}  -  '
                  '${day.precipitationProbabilityMaxPct == null ? '--' : '${day.precipitationProbabilityMaxPct}%'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: _colors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                selected
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: _colors.textMuted,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HOURLY DETAIL (for the selected day)
  Widget _buildHourlyDetailCard(WeatherForecastData data) {
    final days = data.daily;
    if (days.isEmpty || _selectedDayIndex >= days.length) {
      return const SizedBox.shrink();
    }
    final selectedDay = days[_selectedDayIndex];
    final dateStr = selectedDay.time;
    final hours = data.hourly.where((h) => h.time.startsWith(dateStr)).toList();

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Hourly Detail - ${_dayLabel(_parseDate(dateStr), _selectedDayIndex)}',
            Icons.schedule_rounded,
          ),
          SizedBox(height: 12.h),
          if (hours.isEmpty)
            _emptyInline('No hourly data available for this day.')
          else
            SizedBox(
              height: 150.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hours.length,
                separatorBuilder: (_, __) => SizedBox(width: 10.w),
                itemBuilder: (context, i) {
                  final h = hours[i];
                  final precip = h.precipitationMm ?? h.rainMm ?? h.showersMm;
                  return Container(
                    width: 74.w,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? AppColors.dark.surface
                          : AppColors.warmHearth,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _hourLabel(h.time),
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Icon(Icons.water_drop_rounded,
                            size: 16.sp, color: AppColors.riverFlow),
                        SizedBox(height: 4.h),
                        Text(
                          precip == null
                              ? '--'
                              : '${precip.toStringAsFixed(1)} mm',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: _colors.textPrimary,
                          ),
                        ),
                        if (h.precipitationProbabilityPct != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            '${h.precipitationProbabilityPct!.round()}%',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              color: _colors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // WEEKLY SUMMARY CARD
  Widget _buildWeeklySummaryCard(WeatherForecastData data) {
    final summary = computeWeeklySummary(data.daily);
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('7-Day Summary', Icons.summarize_rounded),
          SizedBox(height: 4.h),
          Text(
            'Forecast summaries - not guaranteed rainfall totals.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: _colors.textMuted,
            ),
          ),
          SizedBox(height: 14.h),
          _summaryTile(
            Icons.water_damage_rounded,
            'Total expected rainfall',
            '${summary.totalDisplay} mm',
            'Sum of the 7 daily forecast values',
          ),
          _summaryTile(
            Icons.trending_up_rounded,
            'Wettest day',
            summary.wettestDay == null
                ? 'No data'
                : '${summary.wettestDisplay} mm - ${_dayLabel(_parseDate(summary.wettestDay!.time), data.daily.indexOf(summary.wettestDay!))}',
            'Highest single-day forecast',
          ),
          _summaryTile(
            Icons.percent_rounded,
            'Highest rain probability',
            summary.highestProbabilityPct == null
                ? 'No data'
                : '${summary.highestProbabilityPct}% - ${_dayLabel(_parseDate(summary.highestProbabilityDay!.time), data.daily.indexOf(summary.highestProbabilityDay!))}',
            'Day with the greatest chance of rain',
          ),
          _summaryTile(
            Icons.event_available_rounded,
            'Days with measurable rain',
            '${summary.daysWithMeasurablePrecipitation} of ${summary.dayCount}',
            'Days forecasting more than 0 mm',
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
      IconData icon, String label, String value, String caption) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: AppColors.heritagePurple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 20.sp, color: AppColors.heritagePurple),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.heritagePurple,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  caption,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: _colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WATER LEVEL CARD (honest unavailable state)
  Widget _buildWaterLevelCard(RainForecastState state) {
    final wl = state.waterLevel;
    final available = !wl.isUnavailable;
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('River Water Level', Icons.waves_rounded),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: available
                  ? _RFColors.safe.withValues(alpha: 0.10)
                  : _colors.textMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: available
                    ? _RFColors.safe.withValues(alpha: 0.35)
                    : _colors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  available
                      ? Icons.check_circle_outline
                      : Icons.cloud_off_rounded,
                  size: 20.sp,
                  color: available ? _RFColors.safe : _colors.textMuted,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    wl.message,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      height: 1.5,
                      color: _colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'River stage is a separate measurement (metres) from rainfall '
            '(millimetres). This screen never presents rainfall as a river height.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              height: 1.45,
              color: _colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // SAFETY GUIDANCE CARD
  Widget _buildSafetyGuidanceCard(WeatherForecastData data) {
    final rule = RainRiskClassifier.classifyRainOutlook(
      daily: data.daily,
      location: data.location,
    );
    final tips = _safetyTipsFor(rule.label);
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Safety Guidance', Icons.health_and_safety_rounded),
          SizedBox(height: 4.h),
          Text(
            'Practical, non-alarmist steps to prepare for rain.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: _colors.textMuted,
            ),
          ),
          SizedBox(height: 12.h),
          ...tips.map((tip) => _bullet(tip)),
        ],
      ),
    );
  }

  List<String> _safetyTipsFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('high') || l.contains('heavy')) {
      return const [
        'Avoid low-lying areas and waterways during heavy rain.',
        'Prepare a go-bag and know your nearest evacuation centre.',
        'Charge devices and keep flashlights ready in case of outages.',
        'Follow official PAGASA and MDRRMO advisories closely.',
      ];
    }
    if (l.contains('moderate') || l.contains('isolated')) {
      return const [
        'Watch low-lying areas and small streams for rising water.',
        'Clear drains near your home to reduce local flooding.',
        'Keep important documents in a waterproof bag.',
      ];
    }
    return const [
      'Conditions look calm - a light rain jacket is enough.',
      'Stay updated in case the forecast changes.',
      'Report blocked drainage to your barangay hall.',
    ];
  }

  Widget _bullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Icon(Icons.check_circle_rounded,
                size: 16.sp, color: _RFColors.safe),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                height: 1.45,
                color: _colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ATTRIBUTION CARD
  Widget _buildAttributionCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, size: 16.sp, color: _colors.textMuted),
              SizedBox(width: 6.w),
              Text(
                'Data source',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: _colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Weather data by Open-Meteo.com, distributed under the CC BY 4.0 '
            'licence. Values are area (grid-cell) estimates for Milaor, '
            'Camarines Sur and are not measurements taken inside a barangay. '
            'Flood advisories: monitor PAGASA and your local MDRRMO.',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              height: 1.5,
              color: _colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // SHARED UI HELPERS
  Widget _cardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: AppColors.heritagePurple),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: _colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: _colors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyInline(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16.sp, color: _colors.textMuted),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: _colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DATE HELPERS
  DateTime? _parseDate(String iso) => DateTime.tryParse(iso);

  String _dayLabel(DateTime? date, int index) {
    if (date == null) return 'Day ${index + 1}';
    if (index == 0) return 'Today';
    if (index == 1) return 'Tomorrow';
    return DateFormat('EEEE').format(date);
  }

  String _hourLabel(String isoDateTime) {
    final dt = DateTime.tryParse(isoDateTime);
    if (dt == null) return '--';
    return DateFormat('h a').format(dt);
  }

  String _tempText(WeatherDay day) {
    final max = day.temperatureMaxC;
    final min = day.temperatureMinC;
    if (max == null && min == null) return '--';
    if (max == null) return '$min C';
    if (min == null) return '$max C';
    return '$min / $max C';
  }
}
