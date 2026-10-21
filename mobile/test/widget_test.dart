import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App scaffold renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(430, 932),
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('MAY-LAUD')),
            ),
          ),
        ),
      ),
    );

    expect(find.text('MAY-LAUD'), findsOneWidget);
  });
}
