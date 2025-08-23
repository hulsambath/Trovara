import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/constants/app_color.dart';

class ConnectivityStatus extends StatefulWidget {
  const ConnectivityStatus({super.key});

  @override
  State<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends State<ConnectivityStatus> {
  ConnectivityResult? connectivity;
  bool isRetrying = false;
  int retryCount = 0;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((event) {
      if (event.contains(ConnectivityResult.none)) {
        setConnectivity(ConnectivityResult.none);
        isRetrying = false;
        retryCount = 0;
      } else if (connectivity == ConnectivityResult.none) {
        setConnectivity(event.firstOrNull);
        isRetrying = true;
        retryCount++;
      } else {
        setConnectivity(null);
        isRetrying = false;
        retryCount = 0;
      }
    });
  }

  void setConnectivity(ConnectivityResult? event) {
    if (connectivity != event) {
      connectivity = event;
      if (mounted) setState(() {});
    }
  }

  String _getConnectionMessage() {
    if (connectivity == ConnectivityResult.none) {
      if (retryCount > 0) {
        return tr('msg.connectivity.retrying', args: [retryCount.toString()]);
      }
      return tr('msg.connectivity.no_internet');
    } else if (isRetrying) {
      return tr('msg.connectivity.connected');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (connectivity == null && !isRetrying) return const SizedBox();

    final message = _getConnectionMessage();
    if (message.isEmpty) return const SizedBox();

    if (connectivity == ConnectivityResult.none) {
      return buildMessage(
        text: message,
        context: context,
        foregroundColor: AppColor.onDanger,
        backgroundColor: AppColor.danger,
        iconData: isRetrying ? Icons.sync : Icons.wifi_off,
      );
    } else {
      return FutureBuilder(
        future: Future.delayed(const Duration(seconds: 2)).then((_) => 1),
        builder: (context, snapshot) => AnimatedCrossFade(
          crossFadeState: snapshot.data != 1 ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 300),
          firstChild: buildMessage(
            text: message,
            context: context,
            foregroundColor: AppColor.onSuccess,
            backgroundColor: AppColor.success,
            iconData: Icons.wifi,
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      );
    }
  }

  Widget buildMessage({
    required String text,
    required BuildContext context,
    required Color foregroundColor,
    required Color backgroundColor,
    required IconData iconData,
  }) => AnimatedCrossFade(
    crossFadeState: CrossFadeState.showFirst,
    duration: const Duration(milliseconds: 300),
    firstChild: Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Container(
          decoration: BoxDecoration(color: backgroundColor),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, color: foregroundColor, size: 16),
              const SizedBox(width: 8),
              Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foregroundColor)),
            ],
          ),
        ),
      ),
    ),
    secondChild: const SizedBox(width: double.infinity),
  );
}
