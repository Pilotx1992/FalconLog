import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/flight_logs_provider.dart';
import '../../utils/app_snack_bar.dart';
import '../domain/report_date_range.dart';
import '../providers/flight_report_preview_provider.dart';
import '../services/flight_report_export_coordinator.dart';
import '../services/flight_report_export_outcome.dart';
import 'widgets/report_period_selector.dart';
import 'widgets/report_preview_panel.dart';
import 'widgets/report_section_card.dart';
import 'widgets/report_ui_tokens.dart';

class FlightReportExportScreen extends ConsumerStatefulWidget {
  const FlightReportExportScreen({super.key});

  @override
  ConsumerState<FlightReportExportScreen> createState() =>
      _FlightReportExportScreenState();
}

class _FlightReportExportScreenState
    extends ConsumerState<FlightReportExportScreen> {
  ReportPeriodKind _kind = ReportPeriodKind.thisMonth;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEnd = DateTime.now();
  String? _customError;
  bool _exporting = false;
  late FlightReportPreviewParams _previewParams;

  final _coordinator = FlightReportExportCoordinator();
  static final _displayDateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _previewParams = _buildPreviewParams();
  }

  ReportDateRange get _displayRange => ReportDateRange.resolve(
        kind: _kind,
        customStart: _customStart,
        customEnd: _customEnd,
      );

  FlightReportPreviewParams _buildPreviewParams() {
    return FlightReportPreviewParams(range: _displayRange);
  }

  void _syncPreviewParams() {
    _previewParams = _buildPreviewParams();
  }

  bool get _skipPreview =>
      _kind == ReportPeriodKind.custom && _customError != null;

  ReportDateRange? get _exportRange {
    if (_customError != null) return null;
    if (_kind == ReportPeriodKind.custom) {
      return ReportDateRange.custom(start: _customStart, end: _customEnd);
    }
    return _displayRange;
  }

  void _onPeriodSelected(ReportPeriodKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      if (kind != ReportPeriodKind.custom) {
        _customError = null;
      } else {
        _validateCustom();
      }
      _syncPreviewParams();
    });
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(flightLogsProvider);
    final logsLoading = logsAsync.isLoading;
    final logsError = logsAsync.hasError;
    final previewData = _skipPreview
        ? null
        : ref.watch(flightReportPreviewProvider(_previewParams));
    final previewSummary = previewData?.summary;
    final previewEmpty = !logsLoading &&
        !logsError &&
        !_skipPreview &&
        (previewSummary == null || previewSummary.isEmpty);
    final actionsDisabled = logsLoading ||
        logsError ||
        _exporting ||
        _customError != null ||
        previewEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          'PDF Report',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 22,
            fontFamily: 'Roboto',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: ReportUiTokens.appBarGradient,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: ReportUiTokens.bodyGradient,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              child: ReportSectionCard(
                title: 'Report Period',
                icon: Icons.date_range_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReportPeriodSelector(
                      selected: _kind,
                      onSelected: _onPeriodSelected,
                      displayStart: _displayRange.start,
                      displayEnd: _displayRange.end,
                      customStart: _customStart,
                      customEnd: _customEnd,
                      customError: _customError,
                      onPickStart: () => _pickCustomDate(isStart: true),
                      onPickEnd: () => _pickCustomDate(isStart: false),
                      dateFormat: _displayDateFmt,
                    ),
                    const SizedBox(height: 18),
                    ReportPreviewPanel(
                      range: _displayRange,
                      preview: previewSummary,
                      isLoading: logsLoading,
                      hasError: logsError,
                      onRetry: logsError
                          ? () => ref.invalidate(flightLogsProvider)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildExportFab(actionsDisabled),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_exporting) _buildGeneratingOverlay(),
        ],
      ),
    );
  }

  Widget _buildExportFab(bool actionsDisabled) {
    return Container(
      decoration: BoxDecoration(
        gradient: actionsDisabled ? null : ReportUiTokens.tileGradient,
        shape: BoxShape.circle,
        boxShadow: actionsDisabled
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF3949ab).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: FloatingActionButton(
        onPressed: actionsDisabled ? null : _export,
        backgroundColor:
            actionsDisabled ? Colors.grey.shade400 : Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        disabledElevation: 0,
        child: const Icon(Icons.share_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildGeneratingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: ReportUiTokens.spinnerColor),
                  const SizedBox(height: 16),
                  Text(
                    'Generating PDF report…',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ReportUiTokens.titleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStart : _customEnd,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStart = picked;
      } else {
        _customEnd = picked;
      }
      _validateCustom();
      _syncPreviewParams();
    });
  }

  void _validateCustom() {
    if (isValidCustomRange(_customStart, _customEnd)) {
      _customError = null;
    } else {
      _customError = 'Start date must be on or before end date';
    }
  }

  Future<void> _export() async {
    await _runExport((bytes, name) => _coordinator.sharePdf(
          bytes: bytes,
          fileName: name,
        ));
  }

  Future<void> _runExport(
    Future<FlightReportExportOutcome> Function(Uint8List bytes, String name)
        action,
  ) async {
    final range = _exportRange;
    if (range == null) return;

    setState(() => _exporting = true);
    try {
      final allLogs = ref.read(flightLogsProvider).value ?? [];
      final bytes = await _coordinator.buildPdfBytes(
        allLogs: allLogs,
        range: range,
      );
      final name = _coordinator.fileNameFor(range);
      final outcome = await action(bytes, name);
      if (!mounted) return;
      if (outcome.isSuccess) {
        AppSnackBar.show(context, message: 'Report exported successfully.');
      } else if (outcome.isFailure) {
        AppSnackBar.show(
          context,
          message: outcome.errorMessage ?? 'Export failed.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'Export failed: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
