// lib/screens/app_features/document/document_request_screen.dart
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../home/home.dart';
import '../../home/nav_bar_button.dart';
import '../../../utils/guest_guard.dart';
import '../../../providers/content_providers.dart';
import 'document_tracking_screen.dart';

class DocumentRequestScreen extends ConsumerStatefulWidget {
  const DocumentRequestScreen({super.key});

  @override
  ConsumerState<DocumentRequestScreen> createState() =>
      _DocumentRequestScreenState();
}

class _DocumentRequestScreenState extends ConsumerState<DocumentRequestScreen> {
  bool _isDark = false;
  ColorScheme? _cs;

  // ─── ADAPTIVE COLORS ──────────────────────────────────
  Color get _scaffoldBg => _isDark ? _cs!.background : HomeColors.warmHearth;
  Color get _cardBg => _isDark ? _cs!.surface : HomeColors.cardWhite;
  Color get _cardBg70 => _cardBg.withValues(alpha: 0.7);
  Color get _cardBg60 => _cardBg.withValues(alpha: 0.6);
  Color get _titleText => _isDark ? _cs!.onSurface : HomeColors.deepAnchor;
  Color get _bodyText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.65)
      : AppColors.neutralGray800;
  Color get _mutedText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.45)
      : AppColors.neutralGray500;
  Color get _inputFill =>
      _isDark ? _cs!.surface.withValues(alpha: 0.8) : HomeColors.warmHearth;
  Color get _borderColor => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.15)
      : AppColors.neutralGray200;
  Color get _subtitleText => _isDark
      ? _cs!.onSurface.withValues(alpha: 0.5)
      : AppColors.neutralGray500;
  Color get _dragHandle => _isDark
      ? AppColors.neutralWhite.withValues(alpha: 0.24)
      : const Color(0xFFD1D5DB);

  // urgency backgrounds — dark mode strips the pastel tint
  Color _urgencyBg(String urgency) {
    if (_isDark) return _cs!.surface;
    switch (urgency) {
      case 'Urgent':
        return AppColors.error.withValues(alpha: 0.05);
      case 'Normal':
        return AppColors.successAlt.withValues(alpha: 0.06);
      default:
        return AppColors.warningAlt.withValues(alpha: 0.08);
    }
  }

  // urgency foreground stays the same regardless of mode
  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'Urgent':
        return AppColors.errorDark;
      case 'Normal':
        return AppColors.successAlt;
      default:
        return AppColors.warningAlt;
    }
  }

  // ─── FORM STATE ───────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _additionalNotesController =
      TextEditingController();

  String _selectedDocumentType = 'Business Permit';
  String _selectedUrgency = 'Normal (3-5 days)';
  int _currentStep = 0;

  /// Supporting documents the resident attached. Raw bytes rather than a
  /// `dart:io File` so reading/picking works on web too — see
  /// DocumentAttachment in content_providers.dart.
  final List<DocumentAttachment> _attachedFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // ─── DOCUMENT TYPES ───────────────────────────────────
  final List<Map<String, dynamic>> _documentTypes = [
    {
      'name': 'Business Permit',
      'icon': Icons.store_rounded,
      'fee': 500.0,
      'desc': 'Official permit to operate a business within the municipality',
      'color': const Color(0xFF0056A3),
      'available': true,
    },
    {
      'name': 'Civil Registry Documents',
      'icon': Icons.folder_copy_rounded,
      'fee': 200.0,
      'desc': 'Birth, Death, and Marriage Certificates from the civil registry',
      'color': const Color(0xFF4C229C),
      'available': true,
    },
    {
      'name': 'Tax Declaration',
      'icon': Icons.assessment_rounded,
      'fee': 150.0,
      'desc': 'Official tax declaration document for property assessment',
      'color': const Color(0xFF0C5A43),
      'available': false,
    },
    {
      'name': 'Certificate of Residency',
      'icon': Icons.home_work_rounded,
      'fee': 75.0,
      'desc': 'Proof of residency within the municipality',
      'color': AppColors.successAlt,
      'available': false,
    },
    {
      'name': 'Police Clearance',
      'icon': Icons.local_police_rounded,
      'fee': 150.0,
      'desc': 'Police clearance certificate for employment or travel purposes',
      'color': AppColors.warningAlt,
      'available': false,
    },
    {
      'name': 'Community Tax Certificate (Cedula)',
      'icon': Icons.receipt_rounded,
      'fee': 50.0,
      'desc': 'Community tax certificate required for various transactions',
      'color': const Color(0xFF643EB5),
      'available': false,
    },
    {
      'name': 'Zoning Clearance',
      'icon': Icons.map_rounded,
      'fee': 300.0,
      'desc': 'Clearance certifying property zoning compliance',
      'color': AppColors.neutralGray500,
      'available': false,
    },
    {
      'name': 'Fire Safety Inspection Certificate',
      'icon': Icons.fire_extinguisher_rounded,
      'fee': 250.0,
      'desc': 'Certificate of compliance with fire safety standards',
      'color': AppColors.errorDark,
      'available': false,
    },
    {
      'name': 'Sanitary Permit',
      'icon': Icons.health_and_safety_rounded,
      'fee': 200.0,
      'desc':
          'Permit certifying compliance with health and sanitation standards',
      'color': const Color(0xFFEC4899),
      'available': false,
    },
  ];

  Map<String, dynamic> get _selectedDocMeta =>
      _documentTypes.firstWhere((d) => d['name'] == _selectedDocumentType);

  bool get _selectedIsAvailable =>
      (_selectedDocMeta['available'] as bool?) ?? true;

  final List<Map<String, String>> _urgencyLevels = [
    {'label': 'Normal', 'desc': '3-5 days', 'icon': 'schedule'},
    {'label': 'Standard', 'desc': '1 week', 'icon': 'event_note'},
    {'label': 'Urgent', 'desc': '24 hours', 'icon': 'priority_high'},
  ];

  double get _fee => (_selectedDocMeta['fee'] as num).toDouble();
  bool get _isFree => _fee == 0.0;

  IconData _urgencyIcon(String iconName) {
    switch (iconName) {
      case 'priority_high':
        return Icons.priority_high_rounded;
      case 'event_note':
        return Icons.event_note_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  // ─── PHOTO PICKING ────────────────────────────────────
  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    // Read the bytes up front (rather than holding a `dart:io File`) — that's
    // what the Supabase upload needs, and it keeps the picker working on web
    // where `File` doesn't exist.
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _attachedFiles
        .add(DocumentAttachment(bytes: bytes, filename: image.name)));
  }

  Future<void> _takePhoto() async {
    final XFile? photo =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() => _attachedFiles
        .add(DocumentAttachment(bytes: bytes, filename: photo.name)));
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildPhotoSheet(ctx),
    );
  }

  Widget _buildPhotoSheet(BuildContext ctx) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16.h),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: _dragHandle,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Add Attachment',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: _titleText,
            ),
          ),
          SizedBox(height: 20.h),
          _photoOption(ctx,
              icon: Icons.camera_alt_rounded,
              title: 'Take a Photo',
              subtitle: 'Use your camera', onTap: () {
            Navigator.pop(ctx);
            _takePhoto();
          }),
          _photoOption(ctx,
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Pick from your photos', onTap: () {
            Navigator.pop(ctx);
            _pickImage();
          }),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _photoOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: HomeColors.heritagePurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child:
                      Icon(icon, size: 24.sp, color: HomeColors.heritagePurple),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: _titleText,
                          )),
                      SizedBox(height: 2.h),
                      Text(subtitle,
                          style: TextStyle(fontSize: 13.sp, color: _mutedText)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20.sp, color: _mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _removeFile(int index) => setState(() => _attachedFiles.removeAt(index));

  // ─── DOCUMENT TYPE PICKER ─────────────────────────────
  void _showDocumentTypePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDocTypeSheet(ctx),
    );
  }

  Widget _buildDocTypeSheet(BuildContext ctx) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _dragHandle,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 18.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color:
                            HomeColors.heritagePurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11.r),
                      ),
                      child: Icon(Icons.description_rounded,
                          size: 22.sp, color: HomeColors.heritagePurple),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Select Document Type',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: _titleText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _documentTypes.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (_, index) {
                    final doc = _documentTypes[index];
                    final isSelected = _selectedDocumentType == doc['name'];
                    return _docTypeTile(ctx, doc, isSelected);
                  },
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ),
        );
      },
    );
  }

  Widget _docTypeTile(
      BuildContext ctx, Map<String, dynamic> doc, bool isSelected) {
    final Color accent = doc['color'] as Color;
    final double fee = (doc['fee'] as num).toDouble();
    final bool available = (doc['available'] as bool?) ?? true;

    // tile bg adapts to dark mode
    final tileBg = isSelected
        ? accent.withValues(alpha: 0.06)
        : available
            ? (_isDark ? _cs!.background : HomeColors.warmHearth)
            : (_isDark
                ? _cs!.background.withValues(alpha: 0.5)
                : AppColors.neutralGray200);

    final tileBorder = isSelected
        ? accent
        : available
            ? _borderColor
            : (_isDark
                ? _cs!.onSurface.withValues(alpha: 0.1)
                : const Color(0xFFE0E0E0));

    final iconBg = isSelected
        ? accent.withValues(alpha: 0.12)
        : available
            ? (_isDark
                ? _cs!.onSurface.withValues(alpha: 0.08)
                : AppColors.neutralGray200)
            : (_isDark
                ? _cs!.onSurface.withValues(alpha: 0.05)
                : AppColors.neutralGray200);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available
            ? () {
                setState(() => _selectedDocumentType = doc['name'] as String);
                Navigator.pop(ctx);
              }
            : null,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: tileBorder, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  available ? (doc['icon'] as IconData) : Icons.lock_rounded,
                  size: 26.sp,
                  color: isSelected
                      ? accent
                      : available
                          ? (_isDark
                              ? _cs!.onSurface.withValues(alpha: 0.4)
                              : AppColors.neutralGray500)
                          : _mutedText,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc['name'] as String,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: available
                                  ? (isSelected ? _titleText : _bodyText)
                                  : _mutedText,
                            ),
                          ),
                        ),
                        if (!available)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? AppColors.errorDark.withValues(alpha: 0.15)
                                  : AppColors.error.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                  color: _isDark
                                      ? AppColors.errorDark
                                          .withValues(alpha: 0.3)
                                      : AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.errorDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      available ? (doc['desc'] as String) : 'Not Available',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: available ? _mutedText : AppColors.errorDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                available
                    ? (fee == 0 ? 'FREE' : '₱${fee.toStringAsFixed(0)}')
                    : 'N/A',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: available
                      ? (fee == 0 ? AppColors.successAlt : accent)
                      : _mutedText,
                ),
              ),
              if (isSelected) ...[
                SizedBox(width: 8.w),
                Icon(Icons.check_circle_rounded, size: 22.sp, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── SUBMIT ───────────────────────────────────────────
  Future<void> _submitRequest() async {
    if (GuestGuard.isGuest(ref)) {
      await GuestGuard.showGuestRestrictionDialog(context);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_selectedIsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('This document type is not available.'),
        backgroundColor: AppColors.errorDark,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ));
      return;
    }
    setState(() => _isSubmitting = true);
    // Persist the request so it shows up in the user's real
    // Total/Approved/Pending stats on the Profile screen instead of
    // being a purely cosmetic success dialog.
    //
    // Every field collected on this screen is sent — Full Name, Address,
    // Additional Notes, the urgency level and the attached documents — so the
    // web admin sees the exact request the resident filed (see
    // supabase/document_requests_full_details.sql).
    await ref.read(documentRequestsProvider.notifier).submitRequest(
          documentType: _selectedDocumentType,
          purpose: _purposeController.text.trim(),
          urgency: _selectedUrgency,
          fullName: _fullNameController.text.trim(),
          address: _addressController.text.trim(),
          additionalNotes: _additionalNotesController.text.trim(),
          attachments: List<DocumentAttachment>.from(_attachedFiles),
          fee: '₱${(_selectedDocMeta['fee'] as double).toStringAsFixed(2)}',
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSuccessScreen();
  }

  void _showSuccessScreen() {
    final refId =
        'MLR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final urgencyLabel = _selectedUrgency.split(' ')[0];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildSuccessDialog(ctx, refId, urgencyLabel),
    );
  }

  Widget _buildSuccessDialog(
      BuildContext ctx, String refId, String urgencyLabel) {
    final tipBg = _isDark
        ? const Color(0xFF3A2A00)
        : AppColors.warningAlt.withValues(alpha: 0.08);
    final tipBorder = _isDark
        ? const Color(0xFF7A5800)
        : AppColors.warningAlt.withValues(alpha: 0.4);
    final tipText = _isDark ? AppColors.warningAlt : AppColors.warningAlt;
    final refBg = _isDark ? _cs!.background : _scaffoldBg;
    final refBorder = _isDark
        ? _cs!.onSurface.withValues(alpha: 0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.12);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Container(
        padding: EdgeInsets.all(28.w),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: HomeColors.heritagePurple.withValues(alpha: 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 4.h),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, value, __) => Transform.scale(
                scale: value,
                child: Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), AppColors.successAlt],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successAlt.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded, size: 38.sp, color: _cardBg),
                ),
              ),
            ),
            SizedBox(height: 22.h),
            Text(
              'Request Submitted',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: _titleText,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Your document request has been sent to the Barangay office for processing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: _mutedText, height: 1.5),
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: refBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: refBorder),
              ),
              child: Column(
                children: [
                  Text(
                    'REFERENCE NUMBER',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: _mutedText,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    refId,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: HomeColors.heritagePurple,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            _successDetailRow(
                Icons.description_outlined, 'Document', _selectedDocumentType),
            SizedBox(height: 10.h),
            _successDetailRow(Icons.schedule_outlined, 'Processing',
                '$urgencyLabel Processing'),
            SizedBox(height: 10.h),
            _successDetailRow(
              Icons.receipt_long_outlined,
              'Fee',
              _isFree ? 'Free of Charge' : '₱${_fee.toStringAsFixed(2)}',
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: tipBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: tipBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18.sp, color: AppColors.warningAlt),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Follow this request live on the tracking screen — status updates appear automatically.',
                      style: TextStyle(
                          fontSize: 13.sp, color: tipText, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetForm();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DocumentTrackingScreen()),
                  );
                },
                icon: Icon(Icons.track_changes_rounded, size: 18.sp),
                label: Text('Track My Request',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeColors.heritagePurple,
                  side: BorderSide(
                      color: HomeColors.heritagePurple.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeColors.heritagePurple,
                  foregroundColor: AppColors.neutralWhite,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text('Done',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _successDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 16.sp,
            color: HomeColors.heritagePurple.withValues(alpha: 0.7)),
        SizedBox(width: 10.w),
        Text(label, style: TextStyle(fontSize: 13.sp, color: _mutedText)),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: _titleText,
            )),
      ],
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _fullNameController.clear();
    _addressController.clear();
    _purposeController.clear();
    _additionalNotesController.clear();
    setState(() {
      _selectedDocumentType = 'Business Permit';
      _selectedUrgency = 'Normal (3-5 days)';
      _attachedFiles.clear();
      _currentStep = 0;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _purposeController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20.h),
                _buildStepIndicator(),
                SizedBox(height: 20.h),
                _buildDocumentTypeCard(),
                SizedBox(height: 14.h),
                _buildFeeCard(),
                SizedBox(height: 14.h),
                _buildPersonalInfoCard(),
                SizedBox(height: 14.h),
                _buildUrgencyCard(),
                SizedBox(height: 14.h),
                _buildAttachmentCard(),
                SizedBox(height: 14.h),
                _buildAdditionalNotesCard(),
                SizedBox(height: 14.h),
                _buildSubmitButton(),
                SizedBox(height: 10.h),
                _buildInfoBanner(),
                SizedBox(height: 40.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SLIVER APP BAR ───────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 210.h,
      pinned: true,
      elevation: 0,
      backgroundColor: HomeColors.deepAnchor,
      leading: Padding(
        padding: EdgeInsets.only(left: 16.w, top: 8.h),
        child: InkWell(
          onTap: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainApp()),
            (route) => false,
          ),
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Icon(Icons.arrow_back_rounded,
                size: 20.sp, color: AppColors.neutralWhite),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [HomeColors.deepAnchor, HomeColors.heritagePurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(15.r),
                        ),
                        child: Icon(Icons.description_rounded,
                            size: 28.sp, color: AppColors.neutralWhite),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Document Request',
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutralWhite,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Official Barangay Documents',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.neutralWhite
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Request barangay clearances, certificates, and other official documents.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.neutralWhite.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── STEP INDICATOR ───────────────────────────────────
  Widget _buildStepIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _stepDot(0, 'Select\nDocument'),
          _stepLine(0),
          _stepDot(1, 'Fill\nDetails'),
          _stepLine(1),
          _stepDot(2, 'Submit\nRequest'),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isPast = _currentStep > step;
    final inactiveCircle = _isDark
        ? _cs!.onSurface.withValues(alpha: 0.15)
        : AppColors.neutralGray200;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: isActive ? HomeColors.heritagePurple : inactiveCircle,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: HomeColors.heritagePurple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: isPast
                  ? Icon(Icons.check_rounded,
                      size: 16.sp, color: AppColors.neutralWhite)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.neutralWhite : _mutedText,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? _titleText : _mutedText,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(int fromStep) {
    final isPast = _currentStep > fromStep;
    final inactiveLine = _isDark
        ? _cs!.onSurface.withValues(alpha: 0.12)
        : AppColors.neutralGray200;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(bottom: 24.h),
        child: Container(
          height: 2,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: isPast ? HomeColors.heritagePurple : inactiveLine,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  // ─── DOCUMENT TYPE CARD ───────────────────────────────
  Widget _buildDocumentTypeCard() {
    final doc = _selectedDocMeta;
    final Color accent = doc['color'] as Color;
    final bool available = _selectedIsAvailable;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Document Type'),
          SizedBox(height: 2.h),
          Text('Tap to select the document you need',
              style: TextStyle(fontSize: 13.sp, color: _subtitleText)),
          SizedBox(height: 14.h),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showDocumentTypePicker,
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13.r),
                      ),
                      child: Icon(doc['icon'] as IconData,
                          size: 24.sp, color: accent),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDocumentType,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _titleText,
                                  ),
                                ),
                              ),
                              if (!available)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: _isDark
                                        ? AppColors.errorDark
                                            .withValues(alpha: 0.15)
                                        : AppColors.error
                                            .withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6.r),
                                    border: Border.all(
                                        color: _isDark
                                            ? AppColors.errorDark
                                                .withValues(alpha: 0.3)
                                            : AppColors.error
                                                .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Unavailable',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.errorDark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            doc['desc'] as String,
                            style:
                                TextStyle(fontSize: 13.sp, color: _mutedText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 18.sp, color: accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _purposeController,
            maxLines: 3,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: _titleText),
            decoration: _fieldDecoration(
              'Purpose of request (e.g., Employment, School, Travel)',
              Icons.edit_note_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please specify the purpose';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─── FEE CARD ─────────────────────────────────────────
  Widget _buildFeeCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: _isFree
                  ? (_isDark
                      ? AppColors.successAlt.withValues(alpha: 0.15)
                      : AppColors.successAlt.withValues(alpha: 0.06))
                  : HomeColors.heritagePurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              _isFree
                  ? Icons.verified_user_rounded
                  : Icons.receipt_long_rounded,
              size: 26.sp,
              color: _isFree ? AppColors.successAlt : HomeColors.heritagePurple,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _isFree ? 'Free of Charge' : 'Processing Fee',
                    key: ValueKey(_isFree),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: _titleText,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _isFree
                      ? 'No payment required for this document'
                      : 'Pay at the Municipality Office upon pickup',
                  style: TextStyle(
                      fontSize: 13.sp, color: _mutedText, height: 1.3),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _isFree ? 'FREE' : '₱${_fee.toStringAsFixed(2)}',
              key: ValueKey('${_isFree}_$_fee'),
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color:
                    _isFree ? AppColors.successAlt : HomeColors.heritagePurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PERSONAL INFO CARD ───────────────────────────────
  Widget _buildPersonalInfoCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Personal Information'),
            SizedBox(height: 2.h),
            Text('Provide accurate details for verification',
                style: TextStyle(fontSize: 13.sp, color: _subtitleText)),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _fullNameController,
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: _titleText),
              decoration: _fieldDecoration('Full Name', Icons.person_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            SizedBox(height: 14.h),
            TextFormField(
              controller: _addressController,
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: _titleText),
              decoration:
                  _fieldDecoration('Complete Address', Icons.home_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── URGENCY CARD ─────────────────────────────────────
  Widget _buildUrgencyCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Processing Urgency'),
          SizedBox(height: 2.h),
          Text('Faster processing may include additional fees',
              style: TextStyle(fontSize: 13.sp, color: _subtitleText)),
          SizedBox(height: 16.h),
          ..._urgencyLevels.map((urgency) {
            final urgencyLabel = '${urgency['label']} (${urgency['desc']})';
            final isSelected = _selectedUrgency == urgencyLabel;
            final color = _urgencyColor(urgency['label']!);
            final bg = _urgencyBg(urgency['label']!);
            final icon = _urgencyIcon(urgency['icon']!);
            final inactiveIconBg = _isDark
                ? _cs!.onSurface.withValues(alpha: 0.08)
                : AppColors.neutralGray200;

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedUrgency = urgencyLabel),
                  borderRadius: BorderRadius.circular(14.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: isSelected ? bg : Colors.transparent,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isSelected ? color : _borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.12)
                                : inactiveIconBg,
                            borderRadius: BorderRadius.circular(11.r),
                          ),
                          child: Icon(icon,
                              size: 20.sp,
                              color: isSelected ? color : _mutedText),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                urgency['label']!,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? _titleText : _bodyText,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Estimated: ${urgency['desc']}',
                                style: TextStyle(
                                    fontSize: 13.sp, color: _mutedText),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              size: 22.sp, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── ATTACHMENT CARD ──────────────────────────────────
  Widget _buildAttachmentCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('Attachments'),
              if (_attachedFiles.isNotEmpty)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: HomeColors.heritagePurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${_attachedFiles.length} file${_attachedFiles.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.heritagePurple,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Upload supporting documents like valid ID, proof of address (optional)',
            style:
                TextStyle(fontSize: 13.sp, color: _subtitleText, height: 1.4),
          ),
          SizedBox(height: 16.h),
          if (_attachedFiles.isNotEmpty)
            SizedBox(
              height: 116.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attachedFiles.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  if (index == _attachedFiles.length) {
                    return _buildAddThumb();
                  }
                  return _buildFileThumb(
                      file: _attachedFiles[index], index: index);
                },
              ),
            )
          else
            _buildEmptyAttachment(),
        ],
      ),
    );
  }

  Widget _buildEmptyAttachment() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPhotoSourcePicker,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 30.h),
          decoration: BoxDecoration(
            color: _scaffoldBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: HomeColors.heritagePurple.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: HomeColors.heritagePurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.cloud_upload_rounded,
                    size: 26.sp, color: HomeColors.heritagePurple),
              ),
              SizedBox(height: 12.h),
              Text('Tap to attach files',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.heritagePurple,
                  )),
              SizedBox(height: 4.h),
              Text('Valid ID, proof of address, or other documents',
                  style: TextStyle(fontSize: 13.sp, color: _mutedText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddThumb() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPhotoSourcePicker,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: 104.w,
          height: 116.h,
          decoration: BoxDecoration(
            color: HomeColors.heritagePurple.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: HomeColors.heritagePurple.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(Icons.add_rounded,
              size: 28.sp, color: HomeColors.heritagePurple),
        ),
      ),
    );
  }

  Widget _buildFileThumb({required DocumentAttachment file, required int index}) {
    final fileName = file.filename;
    final fileSize = '${(file.bytes.length / 1024).toStringAsFixed(1)} KB';

    return Stack(
      children: [
        Container(
          width: 104.w,
          height: 116.h,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _scaffoldBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: _isDark
                      ? AppColors.errorDark.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.picture_as_pdf_rounded,
                    size: 20.sp, color: AppColors.errorDark),
              ),
              SizedBox(height: 8.h),
              Text(fileName,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: _titleText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 2.h),
              Text(fileSize,
                  style: TextStyle(fontSize: 9.sp, color: _mutedText)),
            ],
          ),
        ),
        Positioned(
          top: 6.w,
          right: 6.w,
          child: GestureDetector(
            onTap: () => _removeFile(index),
            child: Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: _isDark
                    ? AppColors.neutralWhite.withValues(alpha: 0.24)
                    : AppColors.neutralGray800.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 14.sp, color: AppColors.neutralWhite),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ADDITIONAL NOTES ─────────────────────────────────
  Widget _buildAdditionalNotesCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Additional Notes'),
          SizedBox(height: 2.h),
          Text('Any special instructions or details (optional)',
              style: TextStyle(fontSize: 13.sp, color: _subtitleText)),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _additionalNotesController,
            maxLines: 3,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: _titleText),
            decoration: _fieldDecoration(
              'Write any additional notes here...',
              Icons.sticky_note_2_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SUBMIT BUTTON ────────────────────────────────────
  Widget _buildSubmitButton() {
    final bool canSubmit = _selectedIsAvailable && !_isSubmitting;
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitRequest : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: HomeColors.heritagePurple,
          foregroundColor: AppColors.neutralWhite,
          disabledBackgroundColor:
              HomeColors.heritagePurple.withValues(alpha: 0.5),
          disabledForegroundColor:
              AppColors.neutralWhite.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSubmitting
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 24.w,
                  height: 24.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xB3FFFFFF)),
                  ),
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 20.sp),
                    SizedBox(width: 10.w),
                    Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── INFO BANNER ──────────────────────────────────────
  Widget _buildInfoBanner() {
    final bannerBorder = _isDark
        ? _cs!.onSurface.withValues(alpha: 0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.12);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: HomeColors.heritagePurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.info_outline_rounded,
                size: 18.sp,
                color: HomeColors.heritagePurple.withValues(alpha: 0.7)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Important Reminders',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _titleText,
                    )),
                SizedBox(height: 4.h),
                Text(
                  'Documents are processed during office hours (8 AM – 5 PM, Mon–Fri). '
                  'Present a valid ID when picking up your document. '
                  'Track your request status in the Profile section.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: _bodyText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ───────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
        color: _titleText,
        letterSpacing: -0.2,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14.sp,
        color: _mutedText,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Padding(
        padding: EdgeInsets.only(left: 14.w, right: 10.w),
        child: Icon(icon,
            size: 20.sp,
            color: HomeColors.heritagePurple.withValues(alpha: 0.55)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
            BorderSide(color: HomeColors.heritagePurple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: AppColors.errorDark, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      errorStyle: TextStyle(fontSize: 12.sp, color: AppColors.errorDark),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isDark ? 0.15 : 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }
}
