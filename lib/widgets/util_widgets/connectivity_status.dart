import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:notemyminds/widgets/nm_toast.dart';

class ConnectivityStatus extends StatefulWidget {
  const ConnectivityStatus({super.key});

  @override
  State<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends State<ConnectivityStatus> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityResult? _previousState;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> event) {
    if (!mounted) return;

    if (event.contains(ConnectivityResult.none)) {
      // Lost connection
      _previousState = ConnectivityResult.none;

      final message = tr('msg.connectivity.disconnected');

      NmToast.error(context, message);
    } else if (_previousState == ConnectivityResult.none) {
      // Reconnected after being offline
      _previousState = event.firstOrNull;

      NmToast.success(context, tr('msg.connectivity.connected'));
    } else {
      // Normal state – nothing to show
      _previousState = event.firstOrNull;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// This widget doesn't render anything itself; it only fires toasts.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
