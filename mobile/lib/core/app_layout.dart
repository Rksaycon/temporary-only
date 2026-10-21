import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'spacing.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final bool scrollable;

  const AppLayout({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: AppSpacing.screenPadding,
      child: child,
    );

    return Scaffold(
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 1.sh,
                  ),
                  child: IntrinsicHeight(
                    child: content,
                  ),
                ),
              )
            : content,
      ),
    );
  }
}
