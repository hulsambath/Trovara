import 'package:flutter/widgets.dart';

class DeviceConstants {
  DeviceConstants._();
  static double screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;
  static double screenHeight(BuildContext context) => MediaQuery.sizeOf(context).height;

}
