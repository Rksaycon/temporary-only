import 'package:flutter/material.dart';

class R {
  static double w(BuildContext context) => MediaQuery.of(context).size.width;

  static double h(BuildContext context) => MediaQuery.of(context).size.height;

  static bool isSmall(BuildContext context) => w(context) < 360;
  static bool isNormal(BuildContext context) =>
      w(context) >= 360 && w(context) <= 430;
  static bool isLarge(BuildContext context) => w(context) > 430;
}
