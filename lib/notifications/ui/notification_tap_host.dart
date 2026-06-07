import 'package:flutter/material.dart';

import '../services/notification_route_handler.dart';

/// Processes pending notification tap payloads once after startup.
class NotificationTapHost extends StatefulWidget {
  const NotificationTapHost({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationTapHost> createState() => _NotificationTapHostState();
}

class _NotificationTapHostState extends State<NotificationTapHost> {
  bool _processedPending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_processedPending) return;
    _processedPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationRouteHandler.processPendingPayloadOnStartup();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
