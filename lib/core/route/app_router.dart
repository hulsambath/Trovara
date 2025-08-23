import 'package:auto_route/auto_route.dart';
import 'package:noteminds/core/route/routers/routers.dart';

@AutoRouterConfig(replaceInRouteName: 'View,Route')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => routers;
}
