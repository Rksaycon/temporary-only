// ─── Milaor Hotlines — Professional Resident-Friendly Design ───
// Mirrors FloodColors purple palette for consistent app-wide branding
// 60-30-10: warmHearth canvas (60%), card white surfaces (30%), heritage purple accent (10%)

// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../services/app_services.dart';

// ─── BRAND PALETTE — delegates to AppColors (single source of truth) ───
class HotlineColors {
  static Color get heritagePurple => AppColors.heritagePurple;
  static Color get riverFlow => AppColors.riverFlow;
  static Color get deepAnchor => AppColors.deepAnchor;
  static const Color warmHearth = AppColors.warmHearth;
  static const Color cardWhite = AppColors.cardWhite;

  // Semantic accents
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyRedBg = Color(0xFFFEF2F2);
  static const Color emergencyRedBorder = Color(0xFFFECACA);

  static const Color medicalGreen = Color(0xFF059669);
  static const Color medicalGreenBg = Color(0xFFECFDF5);
  static const Color medicalGreenBorder = Color(0xFFA7F3D0);

  static const Color utilitySlate = Color(0xFF64748B);
  static const Color utilitySlateBg = Color(0xFFF8FAFC);
  static const Color utilitySlateBorder = Color(0xFFCBD5E1);

  static const Color purpleTint = Color(0xFFF3EFFF); // bg for government icon

  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heritagePurple, deepAnchor],
      );
}

// ─── DATA MODEL ────────────────────────────────────────
enum ContactType { emergency, government, health, services, utilities }

class EmergencyContact {
  final String name;
  final String number;
  final String description;
  final ContactType type;
  final IconData icon;

  const EmergencyContact({
    required this.name,
    required this.number,
    required this.description,
    required this.type,
    required this.icon,
  });

  Color get accentColor {
    switch (type) {
      case ContactType.emergency:
        return HotlineColors.emergencyRed;
      case ContactType.health:
        return HotlineColors.medicalGreen;
      case ContactType.government:
        return HotlineColors.riverFlow;
      case ContactType.services:
      case ContactType.utilities:
        return HotlineColors.utilitySlate;
    }
  }

  Color get bgColor {
    switch (type) {
      case ContactType.emergency:
        return HotlineColors.emergencyRedBg;
      case ContactType.health:
        return HotlineColors.medicalGreenBg;
      case ContactType.government:
        return HotlineColors.purpleTint;
      case ContactType.services:
      case ContactType.utilities:
        return HotlineColors.utilitySlateBg;
    }
  }

  Color get borderColor {
    switch (type) {
      case ContactType.emergency:
        return HotlineColors.emergencyRedBorder;
      case ContactType.health:
        return HotlineColors.medicalGreenBorder;
      case ContactType.government:
        return AppColors.heritagePurple.withValues(alpha: 0.3);
      case ContactType.services:
      case ContactType.utilities:
        return HotlineColors.utilitySlateBorder;
    }
  }

  String get typeLabel {
    switch (type) {
      case ContactType.emergency:
        return 'Emergency';
      case ContactType.government:
        return 'Government';
      case ContactType.health:
        return 'Health';
      case ContactType.services:
        return 'Services';
      case ContactType.utilities:
        return 'Utilities';
    }
  }
}

// ─── SUPABASE ROW MAPPING ───────────────────────────────
// The web admin panel's Emergency Hotline page writes rows to the
// `hotlines` table with a `type` of General/Police/Fire/Medical/
// Disaster/Social. Map that onto this screen's ContactType (used for
// color grouping) and an icon.
ContactType _contactTypeFor(String? type) {
  switch (type) {
    case 'Police':
    case 'Fire':
    case 'Disaster':
      return ContactType.emergency;
    case 'Medical':
      return ContactType.health;
    case 'Social':
      return ContactType.services;
    case 'Utility':
      return ContactType.utilities;
    case 'General':
    default:
      return ContactType.government;
  }
}

IconData _iconFor(String? type) {
  switch (type) {
    case 'Police':
      return Icons.local_police_rounded;
    case 'Fire':
      return Icons.fire_truck_rounded;
    case 'Medical':
      return Icons.medical_services_rounded;
    case 'Disaster':
      return Icons.shield_rounded;
    case 'Social':
      return Icons.home_work_rounded;
    case 'Utility':
      return Icons.electrical_services_rounded;
    case 'General':
    default:
      return Icons.account_balance_rounded;
  }
}

// ─── SCREEN ────────────────────────────────────────────
class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key});

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> {
  ContactType? _selectedType;

  // Dark mode helpers — set in build(), used by helper methods
  bool _isDark = false;
  ColorScheme? _cs;
  Color get _scaffoldBg => _isDark ? _cs!.surface : HotlineColors.warmHearth;
  Color get _cardBg => _isDark ? _cs!.surface : HotlineColors.cardWhite;
  Color get _titleText => AppColors.of(context).textPrimary;
  Color get _bodyText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.65)
      : AppTheme.neutralGray800;
  Color get _mutedText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.45)
      : AppTheme.neutralGray500;
  Color get _dividerColor => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.12)
      : AppTheme.neutralGray200;
  Color get _chipBorder =>
      _isDark ? _cs!.onSurface.withValues(alpha: 0.2) : AppTheme.neutralGray200;

  // FIX — this used to be a `late final` list of hardcoded contacts and
  // never touched Supabase, so hotlines added/edited/removed from the web
  // admin panel never showed up here. It's now fetched live from the same
  // `hotlines` table the web panel writes to.
  final HotlineService _hotlineService = HotlineService();
  List<EmergencyContact> _contacts = [];
  bool _loading = true;
  String? _error;

  late final List<Map<String, dynamic>> _filterOptions;

  @override
  void initState() {
    super.initState();
    _filterOptions = [
      {'label': 'All', 'type': null},
      {'label': 'Emergency', 'type': ContactType.emergency},
      {'label': 'Government', 'type': ContactType.government},
      {'label': 'Health', 'type': ContactType.health},
      {'label': 'Services', 'type': ContactType.services},
      {'label': 'Utilities', 'type': ContactType.utilities},
    ];
    _fetchHotlines();
  }

  Future<void> _fetchHotlines() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _hotlineService.fetchHotlines();
      if (!mounted) return;
      setState(() {
        _contacts = rows.map((row) {
          final type = row['type'] as String?;
          final name = (row['name'] as String?)?.trim();
          final number = (row['number'] ?? row['phone'])?.toString().trim();
          return EmergencyContact(
            name: (name == null || name.isEmpty) ? 'Hotline' : name,
            number: (number == null || number.isEmpty) ? '—' : number,
            description: (row['description'] as String?) ??
                (row['category'] as String?) ??
                (type ?? ''),
            type: _contactTypeFor(type),
            icon: _iconFor(type),
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load hotlines. Pull down to try again.';
        _loading = false;
      });
    }
  }

  List<EmergencyContact> get _filtered => _selectedType == null
      ? _contacts
      : _contacts.where((c) => c.type == _selectedType).toList();

  int get _emergencyCount =>
      _contacts.where((c) => c.type == ContactType.emergency).length;

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot dial $number'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HotlineColors.emergencyRed,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSm)),
          margin: EdgeInsets.all(16.w),
        ),
      );
    }
  }

  void _showContactSheet(EmergencyContact c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContactDetailSheet(
          contact: c,
          cardBg: _cardBg,
          scaffoldBg: _scaffoldBg,
          onCall: () {
            Navigator.pop(context);
            _call(c.number);
          }),
    );
  }

  // ─── MAIN BUILD ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _isDark = theme.brightness == Brightness.dark;
    _cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _fetchHotlines,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 40.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildEmergencyBanner(),
                  SizedBox(height: 24.h),
                  _buildFilterChips(),
                  SizedBox(height: 24.h),
                  _buildSectionLabel('Contact Directory', _filtered.length),
                  SizedBox(height: 12.h),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.h),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: HotlineColors.heritagePurple),
                      ),
                    )
                  else if (_error != null)
                    _buildMessageState(_error!, icon: Icons.wifi_off_rounded)
                  else if (_filtered.isNotEmpty)
                    ...List.generate(_filtered.length, (i) {
                      return _buildContactRow(_filtered[i])
                          .animate()
                          .fadeIn(duration: 350.ms, delay: (70 * i).ms)
                          .slideY(begin: 0.06, end: 0, duration: 350.ms);
                    })
                  else if (_contacts.isEmpty)
                    _buildMessageState('No hotlines have been added yet.',
                        icon: Icons.campaign_outlined)
                  else
                    _buildEmptyState(),
                  SizedBox(height: 32.h),
                  _buildFooterTip(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ─────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: HotlineColors.heritagePurple,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: HotlineColors.headerGradient),
      ),
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_rounded, color: AppColors.neutralWhite),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Milaor Hotlines',
        style: GoogleFonts.poppins(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.neutralWhite,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          onPressed: _loading ? null : _fetchHotlines,
          icon:
              const Icon(Icons.refresh_rounded, color: AppColors.neutralWhite),
          tooltip: 'Refresh',
        ),
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: HotlineColors.emergencyRed,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusCircle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emergency_rounded,
                    color: AppColors.neutralWhite, size: 16),
                SizedBox(width: 4.w),
                Text(
                  '$_emergencyCount',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── EMERGENCY BANNER ────────────────────────────────
  Widget _buildEmergencyBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusXl),
        border: Border.all(color: HotlineColors.emergencyRedBorder),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: HotlineColors.emergencyRedBg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: HotlineColors.emergencyRed,
                  size: 28,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'National Emergency Hotline',
                      style: GoogleFonts.poppins(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Available 24 hours, 7 days a week',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: AppTheme.neutralGray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            '911',
            style: GoogleFonts.poppins(
              fontSize: 52.sp,
              fontWeight: FontWeight.w900,
              color: _titleText,
              letterSpacing: 3,
              height: 1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Police · Fire · Ambulance',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: _mutedText,
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: () => _call('911'),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
              label: Text(
                'Call 911 Now',
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HotlineColors.emergencyRed,
                foregroundColor: AppColors.neutralWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTER CHIPS ────────────────────────────────────
  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Category',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: _titleText,
          ),
        ),
        SizedBox(height: 12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _filterOptions.map((opt) {
              final label = opt['label'] as String;
              final type = opt['type'] as ContactType?;
              final isSelected = _selectedType == type;

              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    curve: Curves.easeOutCubic,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? HotlineColors.heritagePurple : _cardBg,
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadiusCircle),
                      border: Border.all(
                        color: isSelected
                            ? HotlineColors.heritagePurple
                            : _chipBorder,
                      ),
                      boxShadow: isSelected ? AppTheme.shadowSm : [],
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.neutralWhite : _mutedText,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── SECTION LABEL ───────────────────────────────────
  Widget _buildSectionLabel(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: _titleText,
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: HotlineColors.heritagePurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusCircle),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: HotlineColors.heritagePurple,
            ),
          ),
        ),
      ],
    );
  }

  // ─── CONTACT ROW ─────────────────────────────────────
  Widget _buildContactRow(EmergencyContact c) {
    final color = c.accentColor;
    final bg = c.bgColor;
    final border = c.borderColor;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        border: Border.all(color: _dividerColor),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
          onTap: () => _showContactSheet(c),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(AppTheme.borderRadiusMd),
                    border: Border.all(color: border),
                  ),
                  child: Icon(c.icon, color: color, size: 24.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: _titleText,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        c.number,
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: HotlineColors.heritagePurple,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius:
                            BorderRadius.circular(AppTheme.borderRadiusSm),
                      ),
                      child: Text(
                        c.typeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    GestureDetector(
                      onTap: () => _call(c.number),
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadiusMd),
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: AppColors.neutralWhite,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── LOADING-ERROR / EMPTY-DIRECTORY STATE ───────────
  // Used both when the fetch itself failed and when it succeeded but the
  // admin simply hasn't added any hotlines yet — distinct from
  // _buildEmptyState() below, which is for "no results for this filter".
  Widget _buildMessageState(String message, {required IconData icon}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Column(
        children: [
          Icon(icon, size: 48.sp, color: _dividerColor),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48.sp, color: _dividerColor),
          SizedBox(height: 12.h),
          Text(
            'No contacts in this category',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FOOTER TIP ──────────────────────────────────────
  Widget _buildFooterTip() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: HotlineColors.purpleTint,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
        border: Border.all(
            color: HotlineColors.heritagePurple.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: HotlineColors.heritagePurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMd),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: HotlineColors.heritagePurple,
              size: 22,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'Save these numbers in your phone. In an emergency, every second counts.',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: HotlineColors.deepAnchor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CONTACT DETAIL BOTTOM SHEET ───────────────────────
class _ContactDetailSheet extends StatelessWidget {
  final EmergencyContact contact;
  final Color cardBg;
  final Color scaffoldBg;
  final VoidCallback onCall;

  const _ContactDetailSheet({
    required this.contact,
    required this.cardBg,
    required this.scaffoldBg,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final color = contact.accentColor;
    final bg = contact.bgColor;

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.borderRadiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.of(context).border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
                ),
                child: Icon(contact.icon, color: color, size: 28.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: GoogleFonts.poppins(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: cardBg == Colors.white
                            ? HotlineColors.deepAnchor
                            : Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.borderRadiusSm),
                      ),
                      child: Text(
                        contact.typeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            contact.description,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: AppColors.of(context).textMuted,
              height: 1.6,
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 18.h),
            decoration: BoxDecoration(
              color: scaffoldBg,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
              border: Border.all(
                  color: HotlineColors.heritagePurple.withValues(alpha: 0.1)),
            ),
            child: Text(
              contact.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 30.sp,
                fontWeight: FontWeight.w800,
                color: HotlineColors.heritagePurple,
                letterSpacing: 2,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_rounded, size: 22),
              label: Text(
                'Call Now',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: AppColors.neutralWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
