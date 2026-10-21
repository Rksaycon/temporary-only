// lib/screens/sign_up/registration_screen.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:may_laud/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:may_laud/providers/auth_provider.dart';
import 'package:may_laud/screens/otp_verification/registration_otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedBarangay;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final List<String> _barangays = [
    "San Roque",
    "Del Rosario",
    "San Jose",
    "Amparado",
    "Lipot",
    "Borongborongan",
    "San Antonio",
    "Capucnasan",
    "Santo Domingo",
    "Alimbuyog",
    "Balagbag",
    "Cabugao",
    "Dalipay",
    "Flordeliz",
    "Mayaopayawan",
    "Maycatmon",
    "Maydaso",
    "San Miguel",
    "San Vicente",
    "Tarusanan"
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_formatPhoneNumber);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.removeListener(_formatPhoneNumber);
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _formatPhoneNumber() {
    final text = _phoneController.text;
    // Remove all non-digit characters
    String digits = text.replaceAll(RegExp(r'\D'), '');

    // Limit to 10 digits (Philippine number without country code)
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    // Format the number: XXX-XXX-XXXX
    String formatted = '';
    if (digits.isNotEmpty) {
      if (digits.length <= 3) {
        formatted = digits;
      } else if (digits.length <= 6) {
        formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
      } else {
        formatted =
            '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
      }
    }

    // Update the text field if the formatted text is different
    if (_phoneController.text != formatted) {
      final selection = _phoneController.selection;
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  String _getRawPhoneNumber() {
    return _phoneController.text.replaceAll(RegExp(r'\D'), '');
  }

  Future<void> _register() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedBarangay == null ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final rawPhone = _getRawPhoneNumber();
    if (rawPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.register(
      name:
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: rawPhone,
      address: _selectedBarangay!,
    );

    if (!mounted) return;

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            email: _emailController.text.trim(),
            name:
                '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
            phone: rawPhone,
            address: _selectedBarangay!,
          ),
        ),
      );
    } else {
      final authState = ref.read(authProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authState.error ?? 'Registration failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showBarangayPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color:
                    sheetDark ? AppColors.deepAnchor : AppColors.neutralWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.w,
                  right: 20.w,
                  top: 12.h,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50.w,
                      height: 5.h,
                      decoration: BoxDecoration(
                        color: sheetDark
                            ? Colors.white24
                            : AppColors.neutralGray200,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(width: 30.w),
                        Text(
                          "Select Barangay",
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: sheetDark
                                ? AppColors.riverFlow
                                : AppColors.heritagePurple,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Icon(Icons.close,
                              color: sheetDark
                                  ? AppColors.riverFlow
                                  : AppColors.heritagePurple),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      height: 300.h,
                      child: ListView.builder(
                        itemCount: _barangays.length,
                        itemBuilder: (context, index) {
                          final item = _barangays[index];
                          return GestureDetector(
                            onTap: () {
                              setModalState(() => _selectedBarangay = item);
                              Navigator.pop(ctx);
                              setState(() {});
                            },
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8.h),
                              padding: EdgeInsets.symmetric(
                                  vertical: 16.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: _selectedBarangay == item
                                    ? (sheetDark
                                        ? AppColors.heritagePurple
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFFF3E5F5))
                                    : (sheetDark
                                        ? AppColors.deepAnchor
                                        : AppColors.neutralWhite),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: _selectedBarangay == item
                                      ? AppColors.heritagePurple
                                      : (sheetDark
                                          ? Colors.white12
                                          : AppColors.neutralGray200),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedBarangay == item
                                          ? (sheetDark
                                              ? AppColors.riverFlow
                                              : AppColors.heritagePurple)
                                          : (sheetDark
                                              ? Colors.white70
                                              : Colors.black87),
                                    ),
                                  ),
                                  Icon(
                                    _selectedBarangay == item
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: _selectedBarangay == item
                                        ? (sheetDark
                                            ? AppColors.riverFlow
                                            : AppColors.heritagePurple)
                                        : (sheetDark
                                            ? Colors.white38
                                            : AppColors.neutralGray500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    // Same adaptive colors as sign-in screen
    final scaffoldBg = isDark ? cs.background : AppColors.neutralWhite;
    final bubbleBg1 = isDark
        ? cs.primary.withOpacity(0.12)
        : AppColors.heritagePurple.withValues(alpha: 0.12);
    final bubbleBg2Gradient = isDark
        ? [cs.primary.withOpacity(0.10), Colors.transparent]
        : [AppColors.riverFlow.withOpacity(0.35), Colors.transparent];
    final bubbleBg3Gradient = isDark
        ? [cs.primary.withOpacity(0.12), Colors.transparent]
        : [AppColors.riverFlow.withOpacity(0.4), Colors.transparent];
    final titleColor = isDark ? cs.onBackground : AppColors.deepAnchor;
    final subtitleColor =
        isDark ? cs.onBackground.withOpacity(0.6) : AppColors.neutralGray500;
    final formBg = isDark ? cs.surface : AppColors.warmHearth;
    final inputBg = isDark ? cs.background : AppColors.neutralWhite;
    final inputBorder =
        isDark ? cs.onSurface.withOpacity(0.15) : AppColors.neutralGray200;
    final inputIconColor =
        isDark ? cs.onSurface.withOpacity(0.5) : AppColors.neutralGray500;
    final labelColor =
        isDark ? cs.onSurface.withOpacity(0.85) : AppColors.neutralGray800;
    final hintColor =
        isDark ? cs.onSurface.withOpacity(0.45) : AppColors.neutralGray500;
    final accentPurple = isDark ? cs.primary : AppColors.heritagePurple;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // Background decorations — same as sign-in
          Positioned(
            top: -120.h,
            left: -120.w,
            child: Container(
              width: 280.w,
              height: 280.w,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: bubbleBg1),
            ),
          ),
          Positioned(
            top: 100.h,
            right: -60.w,
            child: Container(
              width: 160.w,
              height: 160.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: bubbleBg2Gradient),
              ),
            ),
          ),
          Positioned(
            bottom: 180.h,
            right: -80.w,
            child: Container(
              width: 180.w,
              height: 180.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: bubbleBg3Gradient),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 240.h,
              width: double.infinity,
              child: CustomPaint(painter: _WavePainter(isDark: isDark, cs: cs)),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30.h),
                  // Logo — same as sign-in
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.riverFlow.withOpacity(0.18),
                          blurRadius: 25.r,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset('assets/images/milaudlogo.png',
                        height: 100.h),
                  ),
                  SizedBox(height: 15.h),
                  Text(
                    "Create Account",
                    style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Fill in your details to get started",
                    style: TextStyle(fontSize: 14.sp, color: subtitleColor),
                  ),
                  SizedBox(height: 30.h),

                  // Form card — same style as sign-in
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: formBg,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.riverFlow
                              .withOpacity(isDark ? 0.05 : 0.08),
                          blurRadius: 20.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First & Last Name row
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                label: "First Name",
                                icon: Icons.person_outline,
                                controller: _firstNameController,
                                hintText: "First name",
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                inputIconColor: inputIconColor,
                                labelColor: labelColor,
                                cs: cs,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildField(
                                label: "Last Name",
                                icon: Icons.person_outline,
                                controller: _lastNameController,
                                hintText: "Last name",
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                inputIconColor: inputIconColor,
                                labelColor: labelColor,
                                cs: cs,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),

                        // Email
                        _buildField(
                          label: "Email",
                          subtitle: "We'll use this to sign you in",
                          icon: Icons.email_outlined,
                          controller: _emailController,
                          hintText: "Enter your email",
                          keyboardType: TextInputType.emailAddress,
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          inputIconColor: inputIconColor,
                          labelColor: labelColor,
                          hintColor: hintColor,
                          cs: cs,
                        ),
                        SizedBox(height: 20.h),

                        // Phone
                        _buildPhoneField(
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          inputIconColor: inputIconColor,
                          labelColor: labelColor,
                          hintColor: hintColor,
                          cs: cs,
                          isDark: isDark,
                        ),
                        SizedBox(height: 20.h),

                        // Barangay
                        _buildBarangayField(
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          inputIconColor: inputIconColor,
                          labelColor: labelColor,
                          hintColor: hintColor,
                          cs: cs,
                        ),
                        SizedBox(height: 20.h),

                        // Password
                        _buildPasswordField(
                          label: "Password",
                          subtitle:
                              "Create a strong password with at least 8 characters",
                          controller: _passwordController,
                          obscure: _obscurePassword,
                          onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          inputIconColor: inputIconColor,
                          labelColor: labelColor,
                          hintColor: hintColor,
                          hintText: "Enter your password",
                          cs: cs,
                        ),
                        SizedBox(height: 20.h),

                        // Confirm Password
                        _buildPasswordField(
                          label: "Confirm Password",
                          subtitle: "Re-enter your password to confirm",
                          controller: _confirmPasswordController,
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          inputIconColor: inputIconColor,
                          labelColor: labelColor,
                          hintColor: hintColor,
                          hintText: "Confirm your password",
                          cs: cs,
                        ),
                        SizedBox(height: 24.h),

                        // Register button — same gradient as sign-in
                        if (authState.isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          GestureDetector(
                            onTap: _register,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40.r),
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.heritagePurple,
                                    AppColors.riverFlow,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.heritagePurple
                                        .withOpacity(0.3),
                                    blurRadius: 12.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "Register now",
                                  style: TextStyle(
                                      color: AppColors.neutralWhite,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),

                        if (authState.error != null)
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Text(
                              authState.error!,
                              style: TextStyle(
                                  color: AppColors.error, fontSize: 13.sp),
                            ),
                          ),

                        SizedBox(height: 14.h),

                        // Already have account link
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Center(
                            child: RichText(
                              text: TextSpan(
                                text: "Already have an account? ",
                                style: TextStyle(
                                    color: isDark
                                        ? cs.onBackground.withOpacity(0.6)
                                        : Colors.black54,
                                    fontSize: 14.sp),
                                children: [
                                  TextSpan(
                                    text: "Sign In",
                                    style: TextStyle(
                                        color: accentPurple,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),
                  SizedBox(height: 30.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generic text field — mirrors sign-in field style
  Widget _buildField({
    required String label,
    String? subtitle,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    required Color inputBg,
    required Color inputBorder,
    required Color inputIconColor,
    required Color labelColor,
    Color? hintColor,
    required ColorScheme cs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: labelColor)),
        if (subtitle != null) ...[
          SizedBox(height: 4.h),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12.sp,
                  color: hintColor ?? cs.onSurface.withOpacity(0.45))),
        ],
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: inputBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: inputIconColor),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField({
    required Color inputBg,
    required Color inputBorder,
    required Color inputIconColor,
    required Color labelColor,
    required Color hintColor,
    required ColorScheme cs,
    required bool isDark,
  }) {
    final prefixBg = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF5F5F5);
    final prefixText = isDark ? Colors.white70 : const Color(0xFF333333);
    final dividerColor = isDark ? Colors.white12 : AppColors.neutralGray200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Phone Number",
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: labelColor)),
        SizedBox(height: 4.h),
        Text("We'll use this for verification and important updates",
            style: TextStyle(fontSize: 12.sp, color: hintColor)),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: inputBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: prefixBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Text("🇵🇭", style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 6.w),
                    Text("+63",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: prefixText)),
                    SizedBox(width: 4.w),
                    Icon(Icons.keyboard_arrow_down,
                        size: 18.sp, color: inputIconColor),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Container(width: 1.w, height: 24.h, color: dividerColor),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: "Enter your phone number",
                    hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarangayField({
    required Color inputBg,
    required Color inputBorder,
    required Color inputIconColor,
    required Color labelColor,
    required Color hintColor,
    required ColorScheme cs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Barangay",
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: labelColor)),
        SizedBox(height: 4.h),
        Text("Select your barangay to locate your area",
            style: TextStyle(fontSize: 12.sp, color: hintColor)),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _showBarangayPicker,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: inputBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: inputIconColor),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _selectedBarangay ?? "Select your barangay",
                    style: TextStyle(
                      color: _selectedBarangay == null
                          ? cs.onSurface.withOpacity(0.4)
                          : cs.onSurface,
                      fontWeight: _selectedBarangay == null
                          ? FontWeight.normal
                          : FontWeight.w600,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: inputIconColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String subtitle,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required Color inputBg,
    required Color inputBorder,
    required Color inputIconColor,
    required Color labelColor,
    required Color hintColor,
    required String hintText,
    required ColorScheme cs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: labelColor)),
        SizedBox(height: 4.h),
        Text(subtitle, style: TextStyle(fontSize: 12.sp, color: hintColor)),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: inputBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: inputIconColor),
              SizedBox(width: 10.w),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    color: inputIconColor),
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final bool isDark;
  final ColorScheme cs;

  _WavePainter({required this.isDark, required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final fillColor =
        isDark ? cs.primary.withOpacity(0.08) : AppColors.warmHearth;
    final strokeColor =
        isDark ? cs.primary.withOpacity(0.25) : AppColors.riverFlow;

    final fillWave = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final lineWave = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path1 = Path();
    path1.moveTo(0, 70);
    path1.quadraticBezierTo(size.width * 0.25, 20, size.width * 0.5, 90);
    path1.quadraticBezierTo(size.width * 0.75, 150, size.width, 70);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();

    canvas.drawPath(path1, fillWave);

    final path2 = Path();
    path2.moveTo(0, 90);
    path2.quadraticBezierTo(size.width * 0.3, 40, size.width * 0.6, 110);
    path2.quadraticBezierTo(size.width * 0.85, 170, size.width, 100);

    canvas.drawPath(path2, lineWave);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
