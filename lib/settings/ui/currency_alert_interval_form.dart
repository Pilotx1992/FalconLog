import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../currency_alert_settings.dart';

enum CurrencyAlertFormMode { firstRun, edit }

/// Which interval field(s) the form shows (settings can edit one at a time).
enum CurrencyAlertFormScope { both, dayOnly, nightOnly }

/// Shared manual numeric entry for day/night currency alert intervals.
class CurrencyAlertIntervalForm extends StatefulWidget {
  const CurrencyAlertIntervalForm({
    super.key,
    required this.mode,
    this.scope = CurrencyAlertFormScope.both,
    this.initialDayDays,
    this.initialNightDays,
    this.onValidityChanged,
    this.showDisclaimer = true,
  });

  final CurrencyAlertFormMode mode;
  final CurrencyAlertFormScope scope;
  final int? initialDayDays;
  final int? initialNightDays;
  final ValueChanged<bool>? onValidityChanged;
  final bool showDisclaimer;

  @override
  State<CurrencyAlertIntervalForm> createState() =>
      CurrencyAlertIntervalFormState();
}

class CurrencyAlertIntervalFormState extends State<CurrencyAlertIntervalForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dayController;
  late final TextEditingController _nightController;

  @override
  void initState() {
    super.initState();
    final dayText = widget.mode == CurrencyAlertFormMode.edit &&
            widget.initialDayDays != null
        ? '${widget.initialDayDays}'
        : '';
    final nightText = widget.mode == CurrencyAlertFormMode.edit &&
            widget.initialNightDays != null
        ? '${widget.initialNightDays}'
        : '';
    _dayController = TextEditingController(text: dayText);
    _nightController = TextEditingController(text: nightText);
    _dayController.addListener(_notifyValidity);
    _nightController.addListener(_notifyValidity);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyValidity());
  }

  @override
  void dispose() {
    _dayController.removeListener(_notifyValidity);
    _nightController.removeListener(_notifyValidity);
    _dayController.dispose();
    _nightController.dispose();
    super.dispose();
  }

  void _notifyValidity() {
    widget.onValidityChanged?.call(isValid);
  }

  bool get isValid {
    switch (widget.scope) {
      case CurrencyAlertFormScope.both:
        return validateCurrencyAlertDays(_dayController.text) == null &&
            validateCurrencyAlertDays(_nightController.text) == null;
      case CurrencyAlertFormScope.dayOnly:
        return validateCurrencyAlertDays(_dayController.text) == null;
      case CurrencyAlertFormScope.nightOnly:
        return validateCurrencyAlertDays(_nightController.text) == null;
    }
  }

  int? get dayDays => parseCurrencyAlertDays(_dayController.text);
  int? get nightDays => parseCurrencyAlertDays(_nightController.text);

  bool validateAndSave() => _formKey.currentState?.validate() ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDisclaimer) ...[
            Text(
              'Choose how many days FalconLog should use for your day and night currency reminders. You can change these later from Settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'FalconLog provides reminder alerts only. Always follow your official authority, company, or operator requirements.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (widget.scope != CurrencyAlertFormScope.nightOnly) ...[
            if (widget.scope == CurrencyAlertFormScope.dayOnly) ...[
              Text(
                'Reminds you based on your last logged day flight.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _IntervalField(
              label: 'Day currency alert days',
              hint: 'e.g. 15',
              controller: _dayController,
              colorScheme: colorScheme,
            ),
          ],
          if (widget.scope == CurrencyAlertFormScope.both)
            const SizedBox(height: 20),
          if (widget.scope != CurrencyAlertFormScope.dayOnly) ...[
            if (widget.scope == CurrencyAlertFormScope.nightOnly) ...[
              Text(
                'Reminds you based on your last logged night flight.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _IntervalField(
              label: 'Night currency alert days',
              hint: 'e.g. 10',
              controller: _nightController,
              colorScheme: colorScheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _IntervalField extends StatelessWidget {
  const _IntervalField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.colorScheme,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: validateCurrencyAlertDays,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
