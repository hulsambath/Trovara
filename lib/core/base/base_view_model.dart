import 'package:flutter/material.dart';
import 'package:notemyminds/global_widgets/cm_change_notifier.dart';

class BaseViewModel extends CmChangeNotifier {
  String? perPage(BuildContext context) {
    try {
      // Go Router doesn't have the same query parameter access as Auto Route
      // This method can be removed or updated based on actual usage
      return null;
    } catch (e) {
      return null;
    }
  }
}
