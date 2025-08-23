import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/global_widgets/cm_change_notifier.dart';

class BaseViewModel extends CmChangeNotifier {
  String? perPage(BuildContext context) {
    try {
      return context.routeData.queryParams.getString('perPage');
    } catch (e) {
      return null;
    }
  }
}
