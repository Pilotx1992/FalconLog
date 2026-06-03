import 'package:flutter/material.dart';

import '../utils/restore_recovery_notice_store.dart';

class RestoreRecoveryNoticeHost extends StatefulWidget {
  const RestoreRecoveryNoticeHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<RestoreRecoveryNoticeHost> createState() =>
      _RestoreRecoveryNoticeHostState();
}

class _RestoreRecoveryNoticeHostState extends State<RestoreRecoveryNoticeHost> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
  }

  Future<void> _showNotice() async {
    final notice = await RestoreRecoveryNoticeStore.takeLatest();
    if (!mounted || notice == null) {
      return;
    }

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice.message),
        backgroundColor:
            notice.rollbackSucceeded ? null : theme.colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
