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
import 'package:url_launcher/url_launcher.dart';

import '../../home/home.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:may_laud/providers/content_providers.dart';
import '../../home/nav_bar_button.dart';
import '../../../services/app_services.dart';
import '../../../utils/guest_guard.dart'; // ✅ Import guest guard
import 'report_history_screen.dart';
import 'live_detection_camera_screen.dart';

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

enum _ManualCategoryMode { emergency, community }

enum _InjuryAnswer { yes, no, notSure }

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
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  // The model suggests a category from the photos; the citizen confirms or
  // corrects it before submitting. Severity stays hidden and admin-only.
  String? _selectedCategory;
  final List<ReportPhoto> _attachedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isAnalyzingPhotos = false;
  _ManualCategoryMode? _manualCategoryMode;
  bool _isFetchingLocation = false;
  double? _capturedLatitude;
  double? _capturedLongitude;
  int _photoAnalysisGeneration = 0;
  ReportCategorySuggestion? _categorySuggestion;
  final Set<String> _shownEmergencyWarnings = <String>{};
  bool _medicalConfirmationHandled = false;
  AccidentTriageDecision? _accidentTriageDecision;
  FireTriageDecision? _fireTriageDecision;

  final CitizenReportService _reportService = CitizenReportService();
  final HotlineService _hotlineService = HotlineService();

  // These four categories are supported by the emergency photo classifier.
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
      'label': 'Medical / Road Accident',
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

  bool _isEmergencyCategory(String category) =>
      _emergencyCategories.any((item) => item['name'] == category);

  String _categoryLabel(String category) => category == 'Medical Emergency'
      ? 'Medical Emergency / Road Accident'
      : category;

  String _suggestionMessage(ReportCategorySuggestion suggestion) {
    final category = suggestion.suggestedCategory!;
    final label = _categoryLabel(category);
    if (suggestion.contextAvailable) {
      return 'Likely $label\n'
          '${suggestion.contextSummary ?? 'The local image model and context check support the same category.'}';
    }
    final confidence = suggestion.suggestedConfidence?.toStringAsFixed(1);
    if (category == 'Medical Emergency') {
      return 'Possible $label\n'
          'AI confidence: ${confidence ?? 'unknown'}%. Citizen confirmation and admin review are required.';
    }
    return 'AI detected: $label\n'
        'Incident confidence: ${confidence ?? 'unknown'}% '
        'from ${suggestion.supportingPhotoCount} supporting '
        '${suggestion.supportingPhotoCount == 1 ? 'photo' : 'photos'}.';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  // FIX — these used to wrap the picked XFile in a `dart:io File`, which
  // doesn't exist on Flutter web at all ("Unsupported operation:
  // _Namespace" the moment a resident tried attaching a photo there).
  // Reading the bytes up front instead works on every platform, and is
  // what both the Supabase upload and the AI image-verification call
  // need anyway (see ReportPhoto in app_services.dart).
  Future<void> _pickFromGallery() async {
    if (_isSubmitting) return;
    if (_attachedPhotos.length >= CitizenReportService.maxAnalyzedPhotos) {
      _showSnack('You can attach up to 3 photos.');
      return;
    }
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final photo = ReportPhoto(bytes: bytes, filename: image.name);
    setState(() {
      _attachedPhotos.add(photo);
      _shownEmergencyWarnings.clear();
      _medicalConfirmationHandled = false;
      _accidentTriageDecision = null;
      _fireTriageDecision = null;
    });
    await _analyzeAttachedPhotos();
  }

  Future<void> _pickFromCamera() async {
    if (_isSubmitting) return;
    if (_attachedPhotos.length >= CitizenReportService.maxAnalyzedPhotos) {
      _showSnack('You can attach up to 3 photos.');
      return;
    }
    final picked = await Navigator.of(context).push<ReportPhoto>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LiveDetectionCameraScreen(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _attachedPhotos.add(picked);
      _shownEmergencyWarnings.clear();
      _medicalConfirmationHandled = false;
      _accidentTriageDecision = null;
      _fireTriageDecision = null;
    });
    await _analyzeAttachedPhotos();
  }

  Future<void> _removePhoto(int index) async {
    if (_isSubmitting) return;
    setState(() {
      _attachedPhotos.removeAt(index);
      _shownEmergencyWarnings.clear();
      _medicalConfirmationHandled = false;
      _accidentTriageDecision = null;
      _fireTriageDecision = null;
    });
    await _analyzeAttachedPhotos();
  }

  Future<void> _analyzeAttachedPhotos() async {
    final generation = ++_photoAnalysisGeneration;
    final photos = List<ReportPhoto>.of(_attachedPhotos);
    final previousSuggestion = _categorySuggestion?.suggestedCategory;

    if (photos.isEmpty) {
      setState(() {
        _isAnalyzingPhotos = false;
        _categorySuggestion = null;
        _manualCategoryMode = null;
        _selectedCategory = null;
        _accidentTriageDecision = null;
        _fireTriageDecision = null;
      });
      return;
    }

    setState(() {
      _isAnalyzingPhotos = true;
      // Remove a previous AI selection while the changed photo set is being
      // checked. Manual citizen selections are preserved.
      if (_selectedCategory == previousSuggestion) {
        _selectedCategory = null;
      }
    });
    try {
      final suggestion =
          await _reportService.suggestReportCategory(photos: photos);
      if (!mounted || generation != _photoAnalysisGeneration) return;

      for (final result in suggestion.results) {
        debugPrint(
          '[Photo AI] category=${result.detectedCategory}, '
          'categoryConfidence=${result.categoryConfidence}, '
          'valid=${result.isValidPhoto}, '
          'validityConfidence=${result.validityModelConfidence}, '
          'trusted=${result.hasTrustedCategory}',
        );
      }

      final suggestedCategory = suggestion.suggestedCategory;
      setState(() {
        _categorySuggestion = suggestion;
        _isAnalyzingPhotos = false;
        if (suggestedCategory != null) {
          _manualCategoryMode = null;
          // Medical/Road Accident is never finalized from the model alone.
          // The citizen must confirm that somebody needs medical assistance.
          _selectedCategory = suggestedCategory == 'Medical Emergency'
              ? null
              : suggestedCategory;
        } else if (suggestedCategory == null &&
            _selectedCategory == previousSuggestion) {
          // Never leave an old AI-selected category visible after the new
          // photo fails validation or is outside legacy Fire/Flood support.
          _selectedCategory = null;
        }
      });

      // Do not ask severity questions as soon as a photo is analyzed. Let
      // the citizen describe the incident first; the safety check is a
      // fallback at submit time, after the text model has that context.
    } catch (_) {
      if (!mounted || generation != _photoAnalysisGeneration) return;
      setState(() {
        _categorySuggestion = ReportCategorySuggestion(
          checkedPhotoCount: photos.length,
          hasConflictingResults: false,
          aiUnavailable: true,
          results: const [],
        );
        _isAnalyzingPhotos = false;
        if (_selectedCategory == previousSuggestion) {
          _selectedCategory = null;
        }
      });
    }
  }

  Future<void> _selectCategory(String category) async {
    if (category == 'Medical Emergency') {
      setState(() {
        _selectedCategory = category;
        _manualCategoryMode = null;
        _medicalConfirmationHandled = false;
        _accidentTriageDecision = null;
        _fireTriageDecision = null;
      });
      return;
    }
    if (category == 'Fire') {
      setState(() {
        _selectedCategory = 'Fire';
        _manualCategoryMode = null;
        _accidentTriageDecision = null;
        _fireTriageDecision = null;
      });
      return;
    }
    setState(() {
      _selectedCategory = category;
      _accidentTriageDecision = null;
      _fireTriageDecision = null;
    });
  }

  Future<void> _confirmFireUrgency() async {
    if (!mounted) return;
    final answer = await showDialog<_InjuryAnswer>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.local_fire_department_rounded,
          color: Colors.red,
          size: 40,
        ),
        title: const Text('Possible fire'),
        content: const Text(
          'Move away from fire, smoke, and unsafe structures.\n\n'
          'May taong nasa panganib, may bahay o gusaling nanganganib, o mabilis bang kumakalat ang apoy?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _InjuryAnswer.notSure),
            child: const Text('Not sure'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _InjuryAnswer.no),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _InjuryAnswer.yes),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    FireTriageDecision decision;
    if (answer == _InjuryAnswer.yes) {
      decision = FireTriageDecision.peopleOrStructuresInDanger;
    } else if (answer == _InjuryAnswer.no) {
      final uncontrolled = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.orange,
          ),
          title: const Text('Is there an active uncontrolled fire?'),
          content: const Text(
            'Choose No for a controlled cooking fire, supervised burning, or when there is no active danger.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No, controlled / no danger'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, still uncontrolled'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      decision = uncontrolled == true
          ? FireTriageDecision.activeUncontrolledFire
          : FireTriageDecision.controlledOrNoActiveDanger;
    } else {
      decision = FireTriageDecision.notSure;
    }

    setState(() {
      _selectedCategory = 'Fire';
      _manualCategoryMode = null;
      _accidentTriageDecision = null;
      _fireTriageDecision = decision;
    });
  }

  Future<void> _confirmMedicalEmergency({bool force = false}) async {
    if (!mounted || (_medicalConfirmationHandled && !force)) return;
    _medicalConfirmationHandled = true;
    final answer = await showDialog<_InjuryAnswer>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.medical_services_rounded,
          color: Colors.red,
          size: 40,
        ),
        title: const Text('Possible medical emergency or road accident'),
        content: const Text(
          'May nasaktan o may taong nasa agarang panganib?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _InjuryAnswer.notSure),
            child: const Text('Not sure'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _InjuryAnswer.no),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _InjuryAnswer.yes),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    AccidentTriageDecision decision;
    if (answer == _InjuryAnswer.yes) {
      decision = AccidentTriageDecision.injuryOrImmediateDanger;
    } else if (answer == _InjuryAnswer.no) {
      final roadBlocked = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.traffic_rounded, color: Colors.orange),
          title: const Text('Is the road blocked or unsafe?'),
          content: const Text(
            'Choose Yes if vehicles or debris are blocking traffic or creating another danger.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No, road is clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, road is blocked'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      decision = roadBlocked == true
          ? AccidentTriageDecision.noInjuryRoadBlocked
          : AccidentTriageDecision.noInjuryRoadClear;
    } else {
      decision = AccidentTriageDecision.notSure;
    }

    setState(() {
      _selectedCategory = 'Medical Emergency';
      _manualCategoryMode = null;
      _accidentTriageDecision = decision;
      _fireTriageDecision = null;
    });
    if (decision == AccidentTriageDecision.injuryOrImmediateDanger) {
      await _showEmergencyGuidance('Medical Emergency');
    }
  }

  void _enableManualCategoryMode(_ManualCategoryMode mode) {
    final allowedCategories = mode == _ManualCategoryMode.emergency
        ? _emergencyCategories
        : _minorConcernCategories;
    final currentIsAllowed =
        allowedCategories.any((item) => item['name'] == _selectedCategory);
    setState(() {
      _manualCategoryMode = mode;
      if (!currentIsAllowed) {
        _selectedCategory = null;
        _accidentTriageDecision = null;
        _fireTriageDecision = null;
      }
    });
  }

  Future<void> _showEmergencyGuidance(String category) async {
    if (!mounted || !_shownEmergencyWarnings.add(category)) return;
    final isFire = category == 'Fire';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isFire
              ? Icons.local_fire_department_rounded
              : Icons.medical_services_rounded,
          color: Colors.red,
          size: 40,
        ),
        title: Text('Possible ${_categoryLabel(category)}'),
        content: Text(
          '${isFire ? 'Move away from fire, smoke, and unsafe structures.' : 'Keep the person safe and do not move them unless necessary.'}\n\n'
          'This app records a report but does not automatically contact emergency responders. Use your official local emergency contact channel if anyone is in immediate danger.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue report'),
          ),
        ],
      ),
    );
  }

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
      setState(() {
        _locationController.text = address;
        _capturedLatitude = position.latitude;
        _capturedLongitude = position.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not get your location. Please enter it manually.');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  String _locationForSubmission() {
    final address = _locationController.text.trim();
    final landmark = _landmarkController.text.trim();
    final coordinates = _capturedLatitude != null && _capturedLongitude != null
        ? '${_capturedLatitude!.toStringAsFixed(5)}, ${_capturedLongitude!.toStringAsFixed(5)}'
        : '';
    final addressIsCoordinates =
        coordinates.isNotEmpty && address == coordinates;

    return [
      if (landmark.isNotEmpty) 'Landmark: $landmark',
      if (address.isNotEmpty && !addressIsCoordinates) 'Address: $address',
      if (coordinates.isNotEmpty) 'GPS: $coordinates',
    ].join(' • ');
  }

  // ─── SUBMIT REPORT WITH GUEST CHECK ──────────────────
  bool _messageNeedsSafetyFallback(String message) {
    final words = RegExp(r'[A-Za-z]+')
        .allMatches(message)
        .map((match) => match.group(0)!.toLowerCase())
        .where((word) => word.length >= 2)
        .toList(growable: false);

    // Messages such as "may aksidente" or "accident sa kanto" identify an
    // event but do not say whether anybody is injured or still in danger.
    return words.length < 6 || words.toSet().length < 4;
  }

  Future<void> _submitReport() async {
    // ✅ Guest restriction: guests cannot submit reports
    if (GuestGuard.isGuest(ref)) {
      await GuestGuard.showGuestRestrictionDialog(context);
      return;
    }

    if (_isAnalyzingPhotos) {
      _showSnack('Please wait while the photo is being checked.');
      return;
    }

    if (_attachedPhotos.isEmpty) {
      _showSnack('Add a photo of the incident first.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Category has no Form field/validator of its own (it's a chip grid,
    // not a TextFormField) — check it here instead, now that nothing is
    // pre-selected on open.
    var category = _selectedCategory;
    if (category == null) {
      if (_isAnalyzingPhotos) {
        _showSnack('Please wait while the photo is being checked.');
        return;
      }
      // A trusted Medical photo result supplies the category. The safety
      // fallback is considered later, after the completed message is checked.
      if (_categorySuggestion?.suggestedCategory == 'Medical Emergency') {
        category = 'Medical Emergency';
        setState(() => _selectedCategory = category);
      }
      if (category == null) {
        _showSnack('Please confirm or choose a category.');
        return;
      }
    }
    final reportType =
        _isEmergencyCategory(category) ? 'Emergency' : 'Minor Concern';

    // Keep analysis and upload consistent even if the widget rebuilds while
    // the network request is running.
    final photosToSubmit = List<ReportPhoto>.of(_attachedPhotos);

    setState(() => _isSubmitting = true);

    try {
      final description = _descriptionController.text.trim();
      final textSeverity = await _reportService.classifyReportSeverity(
        description: description,
        reportType: reportType,
        category: category,
      );

      // Severity stays admin-only. The citizen sees the simple safety
      // fallback only when the completed message is too short or unclear.
      final textAlreadyFoundHighDanger =
          textSeverity?.toPriorityLevel() == 'High';
      final needsSafetyFallback = reportType == 'Emergency' &&
          !textAlreadyFoundHighDanger &&
          _messageNeedsSafetyFallback(description);

      // Never let an answer retained from an earlier vague submission
      // override a later, sufficiently detailed text-model result.
      if (!needsSafetyFallback &&
          (_accidentTriageDecision != null || _fireTriageDecision != null)) {
        setState(() {
          _accidentTriageDecision = null;
          _fireTriageDecision = null;
        });
      }
      if (needsSafetyFallback &&
          category == 'Medical Emergency' &&
          _accidentTriageDecision == null) {
        await _confirmMedicalEmergency(force: true);
        category = _selectedCategory;
        if (category == null || _accidentTriageDecision == null) return;
      }
      if (needsSafetyFallback &&
          category == 'Fire' &&
          _fireTriageDecision == null) {
        await _confirmFireUrgency();
        category = _selectedCategory;
        if (category == null || _fireTriageDecision == null) return;
      }

      // Emergency reports have no title field (see _buildDetailsCard()) —
      // fall back to the category itself so `subcategory` (a required,
      // non-null DB column) still shows admins something readable
      // instead of an empty string.
      final title = category;

      ReportPhotoAssessment? photoAssessment;
      if (photosToSubmit.isNotEmpty) {
        final cachedSuggestion = _categorySuggestion;
        final cachedMatchesPhotos = cachedSuggestion != null &&
            cachedSuggestion.checkedPhotoCount == photosToSubmit.length;
        final cachedHasTrustedResult = cachedSuggestion?.results
                .any((result) => result.hasTrustedCategory) ==
            true;

        photoAssessment = cachedMatchesPhotos &&
                (reportType == 'Emergency' || cachedHasTrustedResult)
            ? _reportService.assessmentFromSuggestion(
                suggestion: cachedSuggestion,
                category: category,
              )
            : reportType == 'Emergency'
                ? await _reportService.assessReportPhotos(
                    photos: photosToSubmit,
                    category: category,
                    reportType: reportType,
                  )
                : null;
      }

      final submittedLocation = _locationForSubmission();
      final result = await _reportService.submitReport(
        category: category,
        subcategory: title,
        description: description,
        location: submittedLocation,
        photoFiles: photosToSubmit,
        reportType: reportType,
        photoAssessment: photoAssessment,
        accidentTriageDecision: _accidentTriageDecision,
        fireTriageDecision: _fireTriageDecision,
        preclassifiedSeverity: textSeverity,
        severityClassificationAttempted: true,
        // AI assessment runs at submission and is saved for admin review.
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
              description: result['storedDescription'] as String? ??
                  _descriptionController.text.trim(),
              location: submittedLocation,
              status: 'received',
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      _showSuccessDialog(
        reportId: result['reportId'] as String,
        category: category,
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

  Future<Map<String, String>?> _findEmergencyContact(String category) async {
    final wantedType = category == 'Fire'
        ? 'fire'
        : category == 'Medical Emergency'
            ? 'medical'
            : null;
    if (wantedType == null) return null;

    try {
      final rows = await _hotlineService.fetchHotlines();
      for (final row in rows) {
        final type = row['type']?.toString().trim().toLowerCase();
        if (type != wantedType) continue;
        final number = (row['number'] ?? row['phone'])?.toString().trim();
        if (number == null || number.isEmpty) continue;
        final name = row['name']?.toString().trim();
        return {
          'name': name == null || name.isEmpty
              ? (wantedType == 'fire' ? 'BFP' : 'Ambulance')
              : name,
          'number': number,
        };
      }
    } catch (e) {
      debugPrint('Could not load emergency contact: $e');
    }
    return null;
  }

  Future<void> _callEmergencyNumber(String number) async {
    final dialable = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: dialable);
    if (dialable.isNotEmpty && await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (mounted) _showSnack('Could not open the phone dialer for $number.');
  }

  void _showSuccessDialog({
    required String reportId,
    required String category,
  }) {
    final showEmergencyActions =
        category == 'Fire' || category == 'Medical Emergency';
    final localContact = showEmergencyActions
        ? _findEmergencyContact(category)
        : Future<Map<String, String>?>.value(null);
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
          child: SingleChildScrollView(
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                  'Thank you, kababayan! Your report is awaiting LGU verification and office assignment. You will receive a notification when its status changes.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp, color: _mutedText, height: 1.6),
                ),
                if (showEmergencyActions) ...[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      'Immediate danger? This report was saved, but responders have not been contacted. Call now for dispatch.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: _bodyText,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  FutureBuilder<Map<String, String>?>(
                    future: localContact,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      final contact = snapshot.data;
                      if (contact == null) {
                        return Text(
                          'No verified local ${category == 'Fire' ? 'BFP' : 'ambulance'} number is configured yet. Use Unified 911 below.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, color: _mutedText),
                        );
                      }
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _callEmergencyNumber(contact['number']!),
                          icon: const Icon(Icons.phone_in_talk_rounded),
                          label: Text(
                            'Call ${contact['name']} · ${contact['number']}',
                            textAlign: TextAlign.center,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r)),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _callEmergencyNumber('911'),
                      icon: const Icon(Icons.emergency_rounded),
                      label: const Text('Call Unified 911'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r)),
                      ),
                    ),
                  ),
                ],
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
                  _buildPhotoCard(),
                  SizedBox(height: 20.h),
                  _buildCategorySection(),
                  SizedBox(height: 20.h),
                  _buildDetailsCard(),
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

  // ─── CATEGORY SELECTOR ──────────────────────────────
  Widget _buildCategorySection() {
    final suggestion = _categorySuggestion;
    final manualCategories = _manualCategoryMode == null
        ? const <Map<String, dynamic>>[]
        : _manualCategoryMode == _ManualCategoryMode.emergency
            ? _emergencyCategories
            : _minorConcernCategories;

    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('2. Category', Icons.category_rounded),
          SizedBox(height: 16.h),
          if (_isAnalyzingPhotos) ...[
            Row(
              children: [
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Analyzing all ${_attachedPhotos.length} attached ${_attachedPhotos.length == 1 ? 'photo' : 'photos'} as one incident...',
                    style: GoogleFonts.inter(fontSize: 13.sp, color: _bodyText),
                  ),
                ),
              ],
            ),
          ] else if (suggestion?.suggestedCategory != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: ReportColors.heritagePurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                _suggestionMessage(suggestion!),
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: _bodyText,
                  height: 1.4,
                ),
              ),
            ),
          ] else if (_attachedPhotos.isNotEmpty) ...[
            Text(
              suggestion?.contextDecision == 'likely_non_emergency'
                  ? '${suggestion?.contextSummary ?? 'The photos may show a harmless look-alike rather than an active emergency.'} Add a wider photo if danger is present, or use manual reporting.'
                  : suggestion?.contextDecision == 'needs_more_evidence'
                      ? '${suggestion?.contextSummary ?? 'The photos do not show enough evidence yet.'} Add another clear view of the same incident.'
                      : suggestion?.contextDecision == 'possible_emergency'
                          ? 'Possible ${suggestion?.contextSuggestedCategory ?? 'emergency'}, but it cannot be confirmed automatically. ${suggestion?.contextSummary ?? 'Add another clear photo or select the category manually.'}'
                          : suggestion?.aiUnavailable == true
                              ? 'Some photos could not be checked. Try again, add another photo, or use a manual fallback below.'
                              : suggestion?.hasConflictingResults == true
                                  ? 'The photos suggest different emergencies. Add a clearer photo; the app will not guess between them.'
                                  : suggestion?.allPhotosRejectedForAutomaticCategory ==
                                          true
                                      ? 'Invalid or unclear emergency photo. No category was selected, and the raw classifier guess was ignored. Add a clear incident photo or choose a manual report below.'
                                      : 'The emergency is not clear enough yet. Add another view of the same incident to strengthen the result.',
              style: GoogleFonts.inter(
                  fontSize: 13.sp, color: _mutedText, height: 1.4),
            ),
            if (_attachedPhotos.length < CitizenReportService.maxAnalyzedPhotos)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  'You can add ${CitizenReportService.maxAnalyzedPhotos - _attachedPhotos.length} more ${CitizenReportService.maxAnalyzedPhotos - _attachedPhotos.length == 1 ? 'photo' : 'photos'}. Matching evidence is combined automatically.',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: ReportColors.heritagePurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _enableManualCategoryMode(_ManualCategoryMode.emergency),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('Report emergency manually'),
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _enableManualCategoryMode(_ManualCategoryMode.community),
                icon: const Icon(Icons.location_city_rounded),
                label: const Text('Report a community concern'),
              ),
            ),
          ] else ...[
            Text(
              'Add a photo first. The app will suggest a supported emergency category before offering a manual fallback.',
              style: GoogleFonts.inter(fontSize: 13.sp, color: _mutedText),
            ),
          ],
          if (manualCategories.isNotEmpty && !_isAnalyzingPhotos) ...[
            SizedBox(height: 14.h),
            Text(
              _manualCategoryMode == _ManualCategoryMode.emergency
                  ? suggestion?.contextDecision == 'likely_non_emergency'
                      ? 'The photos may show a non-emergency look-alike. If danger is actually present, select what you witnessed; admin verification will be required.'
                      : 'AI could not confirm it. Select the emergency you witnessed; admin verification will be required.'
                  : 'Community concerns are selected manually because the emergency model is not trained for them.',
              style: GoogleFonts.inter(
                  fontSize: 12.sp, color: _mutedText, height: 1.4),
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: manualCategories.map((cat) {
                final category = cat['name'] as String;
                final categoryLabel = cat['label'] as String? ?? category;
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => _selectCategory(category),
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
                        Icon(
                          cat['icon'] as IconData,
                          size: 18.sp,
                          color:
                              isSelected ? (cat['color'] as Color) : _mutedText,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          categoryLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? (cat['color'] as Color)
                                : _bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (_selectedCategory == 'Medical Emergency' &&
              _accidentTriageDecision != null) ...[
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.health_and_safety_rounded,
                      color: Colors.orange),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accident safety check',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _bodyText,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          _accidentTriageDecision!.summary,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: _mutedText,
                            height: 1.35,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _confirmMedicalEmergency(force: true),
                          child: const Text('Change answer'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedCategory == 'Fire' && _fireTriageDecision != null) ...[
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Colors.orange),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fire safety check',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _bodyText,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          _fireTriageDecision!.summary,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: _mutedText,
                            height: 1.35,
                          ),
                        ),
                        TextButton(
                          onPressed: _confirmFireUrgency,
                          child: const Text('Change answer'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
          _sectionHeader('3. Message', Icons.description_rounded),
          SizedBox(height: 16.h),
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
          _sectionHeader('4. Location', Icons.location_on_rounded),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _locationController,
                  hint: 'Street or barangay',
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
          SizedBox(height: 12.h),
          _buildTextField(
            controller: _landmarkController,
            hint: 'Nearest landmark (example: school or chapel)',
            icon: Icons.account_balance_rounded,
          ),
          SizedBox(height: 6.h),
          Text(
            'Optional, but this helps the barangay team find the place faster.',
            style: GoogleFonts.inter(fontSize: 12.sp, color: _mutedText),
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
    final canAddMore =
        _attachedPhotos.length < CitizenReportService.maxAnalyzedPhotos;
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader('1. Add Photo', Icons.camera_alt_rounded),
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
            'Start here. Add up to 3 clear photos so the app can suggest a category.',
            style: GoogleFonts.inter(fontSize: 12.sp, color: _mutedText),
          ),
          SizedBox(height: 16.h),
          if (_attachedPhotos.isNotEmpty)
            SizedBox(
              height: 120.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _attachedPhotos.length + (canAddMore ? 1 : 0),
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
    if (_isSubmitting) return;
    if (_attachedPhotos.length >= CitizenReportService.maxAnalyzedPhotos) {
      _showSnack('You can attach up to 3 photos.');
      return;
    }
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
          onTap: (_isSubmitting || _isAnalyzingPhotos) ? null : _submitReport,
          child: Center(
            child: (_isSubmitting || _isAnalyzingPhotos)
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
              'Your report goes to LGU admin review. Submitting here does not automatically dispatch emergency responders. If danger is immediate, use an official local emergency contact channel.',
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
