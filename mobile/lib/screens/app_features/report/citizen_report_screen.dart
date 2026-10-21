// lib/screens/app_features/report/citizen_report_screen.dart
// ignore_for_file: unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../home/home.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:may_laud/providers/content_providers.dart';
import '../../home/nav_bar_button.dart';
import '../../../services/app_services.dart';
import '../../../utils/guest_guard.dart'; // ✅ Import guest guard
import 'report_history_screen.dart';

// ─── REPORT COLOR PALETTE ─────────────────────────────
class ReportColors {
  static Color get heritagePurple => HomeColors.heritagePurple;
  static Color get deepAnchor => HomeColors.deepAnchor;
  static const Color warmHearth = HomeColors.warmHearth;
  static const Color cardWhite = HomeColors.cardWhite;
  static Color get riverFlow => HomeColors.riverFlow;

  static const Color priorityLow = Color(0xFF22C55E);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityHigh = Color(0xFFF97316);
  static const Color priorityEmergency = Color(0xFFEF4444);

  static LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [deepAnchor, heritagePurple],
      );

  static LinearGradient get submitGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [heritagePurple, riverFlow],
      );
}

class CitizenReportScreen extends ConsumerStatefulWidget {
  const CitizenReportScreen({super.key});

  @override
  ConsumerState<CitizenReportScreen> createState() =>
      _CitizenReportScreenState();
}

class _CitizenReportScreenState extends ConsumerState<CitizenReportScreen> {
  bool _isDark = false;
  ColorScheme? _cs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    _isDark = brightness == Brightness.dark;
    _cs = Theme.of(context).colorScheme;
  }

  // Dark mode palette — matches home.dart's deep navy-purple brand tones
  static const Color _darkSurface =
      Color(0xFF0D0D1A); // deepest navy scaffold (richer than home's bg)
  static const Color _darkCard = Color(0xFF1E1E2E); // home card colour exactly
  static const Color _darkElevated =
      Color(0xFF16162A); // slightly deeper elevated surface

  Color get _scaffoldBg => _isDark ? _darkSurface : ReportColors.warmHearth;
  Color get _cardBg => _isDark ? _darkCard : ReportColors.cardWhite;
  Color get _titleText => _isDark ? Colors.white : ReportColors.deepAnchor;
  Color get _bodyText =>
      _isDark ? const Color(0xFFCFCFE8) : const Color(0xFF374151);
  Color get _mutedText => _isDark ? Colors.white60 : AppColors.neutralGray500;

  // Text/icon color for content sitting on the SliverAppBar's purple
  // gradient specifically — that gradient is the same in both light
  // and dark mode (an intentional brand element, same pattern as the
  // home/profile headers), so this must NOT use the theme-adaptive
  // _titleText above. Light mode's _titleText resolves to
  // ReportColors.deepAnchor, which is literally one of the two colors
  // in headerGradient — using it here is what made "Report an Issue"
  // nearly invisible against its own background.
  static const Color _headerText = Colors.white;
  Color get _inputFill => _isDark ? _darkElevated : ReportColors.warmHearth;
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.10) : AppColors.neutralGray200;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // 'Emergency' | 'Minor Concern' — matches api.py's `report_type` field
  // exactly (see ReportRequest/classify_report() in api.py). 'Minor
  // Concern' makes the backend force severity to 'Low' without even
  // running the model.
  String _reportType = 'Emergency';
  // Citizens choose a basic category; AI findings are saved for admin review.
  String? _selectedCategory;
  final List<ReportPhoto> _attachedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  final CitizenReportService _reportService = CitizenReportService();

  // FIX — Fire/Flooding used to live in one combined list alongside the
  // routine categories below. Now that there's a separate Emergency /
  // Minor Concern toggle (matching api.py's own report_type concept —
  // 'Minor Concern' forces Low severity without even running the model),
  // keeping them there too would let a resident tag a house fire as a
  // "minor concern" and have it auto-downgraded. Split by report type
  // instead; _categories below picks the right list for whichever is
  // currently selected.
  final List<Map<String, dynamic>> _emergencyCategories = [
    {
      'name': 'Fire',
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFEA580C)
    },
    {
      'name': 'Flooding',
      'icon': Icons.water_damage_rounded,
      'color': const Color(0xFF0891B2)
    },
    {
      'name': 'Medical Emergency',
      'icon': Icons.medical_services_rounded,
      'color': const Color(0xFFEF4444)
    },
    {
      'name': 'Infrastructure Damage',
      'icon': Icons.warning_amber_rounded,
      'color': const Color(0xFF6366F1)
    },
  ];

  // FIX — 'Infrastructure' used to sit here too, alongside 'Infrastructure
  // Damage' under Emergency — two categories covering the same concept
  // in different modes. Removed here; damaged infrastructure now only
  // ever goes under Emergency.
  final List<Map<String, dynamic>> _minorConcernCategories = [
    {
      'name': 'Sanitation',
      'icon': Icons.cleaning_services_rounded,
      'color': const Color(0xFF22C55E)
    },
    {
      'name': 'Security',
      'icon': Icons.security_rounded,
      'color': const Color(0xFF0EA5E9)
    },
    {
      'name': 'Traffic',
      'icon': Icons.traffic_rounded,
      'color': const Color(0xFFF59E0B)
    },
    {
      'name': 'Environment',
      'icon': Icons.eco_rounded,
      'color': const Color(0xFF10B981)
    },
    {
      'name': 'Health',
      'icon': Icons.medical_services_rounded,
      'color': const Color(0xFFEF4444)
    },
    {
      'name': 'Other',
      'icon': Icons.more_horiz_rounded,
      'color': const Color(0xFF8B5CF6)
    },
  ];

  List<Map<String, dynamic>> get _categories => _reportType == 'Emergency'
      ? _emergencyCategories
      : _minorConcernCategories;

  void _setReportType(String type) {
    if (_reportType == type) return;
    setState(() {
      _reportType = type;
      // The previously-selected category (if any) may not exist in the
      // new list at all (e.g. switching away from Emergency loses
      // "Fire") — clear it rather than leaving a stale, invisible
      // selection. Matches the "nothing pre-selected" rule below.
      _selectedCategory = null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // FIX — these used to wrap the picked XFile in a `dart:io File`, which
  // doesn't exist on Flutter web at all ("Unsupported operation:
  // _Namespace" the moment a resident tried attaching a photo there).
  // Reading the bytes up front instead works on every platform, and is
  // what both the Supabase upload and the AI image-verification call
  // need anyway (see ReportPhoto in app_services.dart).
  Future<void> _pickFromGallery() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final photo = ReportPhoto(bytes: bytes, filename: image.name);
    setState(() => _attachedPhotos.add(photo));
  }

  Future<void> _pickFromCamera() async {
    final XFile? photo =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    final picked = ReportPhoto(bytes: bytes, filename: photo.name);
    setState(() => _attachedPhotos.add(picked));
  }

  void _removePhoto(int index) => setState(() {
        _attachedPhotos.removeAt(index);
      });

  // Fill the location field using the device GPS.
  Future<void> _useCurrentLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    try {
      // 1. Make sure location services are actually on.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showSnack('Turn on location services to use this.');
        return;
      }

      // 2. Check / request permission.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _showSnack('Location permission was denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showSnack(
            'Location permission is permanently denied. Enable it from app settings.');
        return;
      }

      // 3. Fetch the current position.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      // 4. Reverse-geocode to a human-readable address so the field matches
      // the "Street, Barangay, or Landmark" hint instead of showing raw
      // coordinates.
      String address =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality, // barangay, in PH addresses
            p.locality, // municipality/city
          ].where((s) => s != null && s.trim().isNotEmpty).toSet().toList();
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {
        // Reverse geocoding can fail (no network, no geocoder on device).
        // Fall back to the raw coordinates already set above rather than
        // blocking the resident from submitting the report.
      }

      if (!mounted) return;
      setState(() => _locationController.text = address);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not get your location. Please enter it manually.');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ─── SUBMIT REPORT WITH GUEST CHECK ──────────────────
  Future<void> _submitReport() async {
    // ✅ Guest restriction: guests cannot submit reports
    if (GuestGuard.isGuest(ref)) {
      await GuestGuard.showGuestRestrictionDialog(context);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Category has no Form field/validator of its own (it's a chip grid,
    // not a TextFormField) — check it here instead, now that nothing is
    // pre-selected on open.
    final category = _selectedCategory;
    if (category == null) {
      _showSnack('Please select a category.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Emergency reports have no title field (see _buildDetailsCard()) —
      // fall back to the category itself so `subcategory` (a required,
      // non-null DB column) still shows admins something readable
      // instead of an empty string.
      final title =
          _reportType == 'Emergency' ? category : _titleController.text.trim();

      final result = await _reportService.submitReport(
        category: category,
        subcategory: title,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        photoFiles: _attachedPhotos,
        reportType: _reportType,
        // Severity is classified by the service for admin review.
      );

      if (!mounted) return;
      // Put the freshly-saved report into the live history provider right
      // now — the report history screen shows it immediately (and keeps it
      // current via realtime) without waiting for a fetch round trip.
      final now = DateTime.now();
      ref.read(citizenReportsProvider.notifier).addReport(
            CitizenReport(
              id: result['reportId'] as String,
              category: category,
              subcategory: title,
              description: _descriptionController.text.trim(),
              location: _locationController.text.trim(),
              status: 'received',
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      _showSuccessDialog(
        reportId: result['reportId'] as String,
        assignedTo: result['assignedTo'] as String,
        estimatedResolution: result['estimatedResolution'] as String,
      );
    } catch (e) {
      if (!mounted) return;
      // FIX — surface the real reason instead of a generic message, so a
      // storage/RLS/network failure is diagnosable instead of a guess.
      // Common causes: the `report-photos` storage bucket doesn't exist
      // yet, or its policies don't allow the signed-in resident to upload.
      debugPrint('Citizen report submission failed: $e');
      _showSnack(_friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('bucket not found') || msg.contains('report-photos')) {
      return 'Could not upload your photo (storage isn\'t set up yet). '
          'Try submitting without a photo, or contact support.';
    }
    if (msg.contains('row-level security') || msg.contains('policy')) {
      return 'You don\'t have permission to submit this report right now. '
          'Please contact support.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showSuccessDialog({
    required String reportId,
    required String assignedTo,
    required String estimatedResolution,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(28.w),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF1B3A2A)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Icon(Icons.check_circle_rounded,
                    size: 40,
                    color: _isDark
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFF2E7D32)),
              ),
              SizedBox(height: 20.h),
              Text(
                'Report Submitted!',
                style: GoogleFonts.poppins(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: _titleText),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _scaffoldBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  reportId,
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: ReportColors.heritagePurple,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Thank you, kababayan! Your concern has been forwarded to $assignedTo. Estimated resolution: $estimatedResolution.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14.sp, color: _mutedText, height: 1.6),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainApp()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ReportColors.heritagePurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK, understood',
                    style: GoogleFonts.inter(
                        fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              // Shortcut straight to the realtime history so the resident can
              // start watching the report move Received → Ongoing → Solved.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ReportHistoryScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ReportColors.heritagePurple,
                    side: BorderSide(color: ReportColors.heritagePurple),
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text(
                    'Track this report',
                    style: GoogleFonts.inter(
                        fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(12.w),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 40.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildReportTypeToggle(),
                  SizedBox(height: 20.h),
                  _buildCategorySection(),
                  SizedBox(height: 20.h),
                  _buildDetailsCard(),
                  SizedBox(height: 20.h),
                  _buildPhotoCard(),
                  SizedBox(height: 20.h),
                  _buildLocationCard(),
                  SizedBox(height: 24.h),
                  _buildSubmitButton(),
                  SizedBox(height: 16.h),
                  _buildInfoBanner(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SLIVER APP BAR ─────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.h,
      pinned: true,
      elevation: 0,
      backgroundColor: ReportColors.heritagePurple,
      // Entry point to the resident's report history — the realtime tracker
      // where every past report shows its live Received/Ongoing/Solved status.
      actions: [
        IconButton(
          tooltip: 'My report history',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportHistoryScreen()),
          ),
          icon: const Icon(Icons.history_rounded, color: Colors.white),
        ),
        SizedBox(width: 4.w),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: ReportColors.headerGradient),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          color: _cardBg.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Icon(Icons.report_problem_rounded,
                            color: _headerText, size: 26),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CITIZEN REPORT',
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white54,
                                letterSpacing: 3,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Report an Issue',
                              style: GoogleFonts.poppins(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color: _headerText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Help improve Milaor by reporting community issues. Your report will be reviewed by the appropriate department.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.white60,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── EMERGENCY / MINOR CONCERN TOGGLE ────────────────
  // Matches api.py's `report_type` field exactly — 'Minor Concern' makes
  // the backend force Low severity without even running the model.
  Widget _buildReportTypeToggle() {
    Widget segment(String type, String label, IconData icon) {
      final isSelected = _reportType == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setReportType(type),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color:
                  isSelected ? ReportColors.heritagePurple : Colors.transparent,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16.sp, color: isSelected ? Colors.white : _mutedText),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isSelected ? Colors.white : _mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          segment('Emergency', 'EMERGENCY', Icons.warning_rounded),
          segment('Minor Concern', 'MINOR CONCERN',
              Icons.lightbulb_outline_rounded),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ─── CATEGORY SELECTOR ──────────────────────────────
  Widget _buildCategorySection() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Category', Icons.category_rounded),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat['name'];
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCategory = cat['name'];
                }),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (cat['color'] as Color).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color:
                          isSelected ? (cat['color'] as Color) : _borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'] as IconData,
                          size: 18.sp,
                          color: isSelected
                              ? (cat['color'] as Color)
                              : _mutedText),
                      SizedBox(width: 6.w),
                      Text(
                        cat['name'],
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSelected ? (cat['color'] as Color) : _bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedCategory == null) ...[
            SizedBox(height: 10.h),
            Text(
              'Select the category that best describes your concern.',
              style: GoogleFonts.inter(fontSize: 11.sp, color: _mutedText),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0);
  }

  // ─── DETAILS CARD ───────────────────────────────────
  Widget _buildDetailsCard() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Issue Details', Icons.description_rounded),
          SizedBox(height: 16.h),
          // FIX — no title field for Emergency reports: someone reporting
          // a fire shouldn't have to stop and compose a short title
          // before they can describe what's happening. Removed from the
          // widget tree entirely here (not just hidden) so its
          // validator doesn't run and block submission — this is what
          // was silently blocking "Submit Report" whenever the title was
          // left blank. Minor Concern keeps it; a short label still
          // helps admins scan a queue of routine complaints.
          if (_reportType != 'Emergency') ...[
            _buildTextField(
              controller: _titleController,
              hint: 'Brief title of the issue',
              icon: Icons.title_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a title'
                  : null,
            ),
            SizedBox(height: 14.h),
          ],
          _buildTextField(
            controller: _descriptionController,
            hint:
                'Describe the issue in detail — what happened, when, and who is affected...',
            icon: Icons.article_rounded,
            maxLines: 5,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter a description'
                : null,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ─── LOCATION CARD ──────────────────────────────────
  Widget _buildLocationCard() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Location', Icons.location_on_rounded),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _locationController,
                  hint: 'Street, Barangay, or Landmark',
                  icon: Icons.pin_drop_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a location'
                      : null,
                ),
              ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: _isFetchingLocation ? null : _useCurrentLocation,
                child: Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: ReportColors.heritagePurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                        color: ReportColors.heritagePurple
                            .withValues(alpha: 0.15)),
                  ),
                  child: _isFetchingLocation
                      ? Padding(
                          padding: EdgeInsets.all(14.w),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                ReportColors.heritagePurple),
                          ),
                        )
                      : Icon(Icons.my_location_rounded,
                          size: 22.sp, color: ReportColors.heritagePurple),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }

  // ─── PHOTO CARD ─────────────────────────────────────
  Widget _buildPhotoCard() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('Photo Evidence', Icons.camera_alt_rounded),
              if (_attachedPhotos.isNotEmpty)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: ReportColors.heritagePurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${_attachedPhotos.length} attached',
                    style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: ReportColors.heritagePurple),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Photos help us understand the issue better (optional)',
            style: GoogleFonts.inter(fontSize: 12.sp, color: _mutedText),
          ),
          SizedBox(height: 16.h),
          if (_attachedPhotos.isNotEmpty)
            SizedBox(
              height: 120.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _attachedPhotos.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  if (index == _attachedPhotos.length) return _addPhotoThumb();
                  return _photoThumb(index);
                },
              ),
            )
          else
            _emptyPhotoArea(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 400.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _emptyPhotoArea() {
    return GestureDetector(
      onTap: _showPhotoSourcePicker,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 32.h),
        decoration: BoxDecoration(
          color: _scaffoldBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
              color: ReportColors.heritagePurple.withValues(alpha: 0.15),
              width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: ReportColors.heritagePurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(Icons.add_a_photo_rounded,
                  size: 26.sp, color: ReportColors.heritagePurple),
            ),
            SizedBox(height: 12.h),
            Text(
              'Tap to add photos',
              style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: ReportColors.heritagePurple),
            ),
            SizedBox(height: 4.h),
            Text(
              'Gallery or Camera',
              style: GoogleFonts.inter(fontSize: 12.sp, color: _mutedText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addPhotoThumb() {
    return GestureDetector(
      onTap: _showPhotoSourcePicker,
      child: Container(
        width: 110.w,
        height: 120.h,
        decoration: BoxDecoration(
          color: ReportColors.heritagePurple.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
              color: ReportColors.heritagePurple.withValues(alpha: 0.2),
              width: 1.5),
        ),
        child: Icon(Icons.add_rounded,
            size: 30.sp,
            color: ReportColors.heritagePurple.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _photoThumb(int index) {
    return Stack(
      children: [
        Container(
          width: 110.w,
          height: 120.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            image: DecorationImage(
                image: MemoryImage(_attachedPhotos[index].bytes),
                fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 6.w,
          right: 6.w,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              width: 26.w,
              height: 26.w,
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: 15.sp, color: _cardBg),
            ),
          ),
        ),
      ],
    );
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 20.h),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                  color: _isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.neutralGray200,
                  borderRadius: BorderRadius.circular(2.r)),
            ),
            SizedBox(height: 22.h),
            Text('Add Photo',
                style: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: _titleText)),
            SizedBox(height: 22.h),
            _photoOption(
              icon: Icons.camera_alt_rounded,
              title: 'Take a Photo',
              subtitle: 'Use your camera',
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            _photoOption(
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Pick from your photos',
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  Widget _photoOption(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: ReportColors.heritagePurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(icon, size: 24.sp, color: ReportColors.heritagePurple),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
              fontSize: 15.sp, fontWeight: FontWeight.w600, color: _titleText)),
      subtitle: Text(subtitle,
          style: GoogleFonts.inter(fontSize: 13.sp, color: _mutedText)),
    );
  }

  // ─── SUBMIT BUTTON ──────────────────────────────────
  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 58.h,
      decoration: BoxDecoration(
        gradient: ReportColors.submitGradient,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: ReportColors.heritagePurple.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: _isSubmitting ? null : _submitReport,
          child: Center(
            child: _isSubmitting
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: _cardBg, size: 22),
                      SizedBox(width: 10.w),
                      Text(
                        'Submit Report',
                        style: GoogleFonts.poppins(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: _cardBg,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms);
  }

  // ─── INFO BANNER ────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
            color: _isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE8E0F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: ReportColors.heritagePurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.info_outline_rounded,
                size: 20.sp, color: ReportColors.heritagePurple),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Your report will be reviewed within 24–48 hours. For emergencies, please call the Milaor hotline directly.',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: _mutedText,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }

  // ─── SHARED HELPERS ─────────────────────────────────
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(24.r),
      border: _isDark
          ? Border.all(color: Colors.white.withValues(alpha: 0.06))
          : null,
      boxShadow: [
        BoxShadow(
          color: _isDark
              ? Colors.black.withValues(alpha: 0.30)
              : ReportColors.heritagePurple.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: ReportColors.heritagePurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18.sp, color: ReportColors.heritagePurple),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: _titleText,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(
          fontSize: 15.sp, fontWeight: FontWeight.w500, color: _titleText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 14.sp, color: AppColors.neutralGray500),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 4.w),
          child: Icon(icon,
              size: 20.sp,
              color: ReportColors.heritagePurple.withValues(alpha: 0.5)),
        ),
        filled: true,
        fillColor: _inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide:
              BorderSide(color: ReportColors.heritagePurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w, vertical: maxLines > 1 ? 16.h : 14.h),
      ),
      validator: validator,
    );
  }
}
