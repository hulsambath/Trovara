import 'package:flutter/material.dart';

class AppConstants {
  static const Locale fallbackLocale = Locale('en');

  static void unFocusNode(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  static const supportedLocales = [Locale('en'), Locale('km')];
}
