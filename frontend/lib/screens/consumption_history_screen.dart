import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../util/format.dart';
import '../util/open_url.dart';
import '../util/status.dart';
import '../widgets/empty_state.dart';

/// What left stock and why (#322). The backend has had the log, its filters
/// and a CSV export all along; until now the only way to read it was to
/// export a spreadsheet and open it somewhere else -- not a workflow on a
/// phone or in an Ingress webview.
class ConsumptionHistoryScreen extends StatefulWidget {
  const ConsumptionHistoryScreen({super.key});

  @override
  State<ConsumptionHistoryScreen> createState() => _ConsumptionHistoryScreenState();
}

/// Ranges offered as chips. `null` days means "everything".
const _ranges = <int?>[7, 30, null];

class _ConsumptionHistoryScreenState extends State<ConsumptionHistoryScreen> {
  int? _days = 30;
  String? _reason;
  List<ConsumptionLogEntry> _entries = [];
  ConsumptionSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? get _since =>
      _days == null ? null : DateTime.now().subtract(Duration(days: _days! - 1));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiClient>();
    try {
      // The summary is deliberately server-side rather than summed from
      // [_entries]: it must stay right when the reason filter narrows the
      // list, and it's the same window either way.
      final results = await Future.wait([
        api.listConsumptionLog(since: _since, reason: _reason),
        api.consumptionSummary(since: _since),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<ConsumptionLogEntry>;
        _summary = results[1] as ConsumptionSummary;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final url = context.read<ApiClient>().exportConsumptionLogCsvUrl();
    try {
      await openInBrowser(url.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotExport('$e'))));
      }
    }
  }

  String _rangeLabel(AppLocalizations l10n, int? days) =>
      days == null ? l10n.historyRangeAll : l10n.historyRangeLastDays(days);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.consumptionHistoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.exportConsumptionLogCsvTitle,
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final days in _ranges)
                    ChoiceChip(
                      label: Text(_rangeLabel(l10n, days)),
                      selected: _days == days,
                      onSelected: (_) {
                        setState(() => _days = days);
                        _load();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in <String?>[null, 'used', 'spoiled'])
                    ChoiceChip(
                      label: Text(
                        reason == null
                            ? l10n.historyReasonAll
                            : reason == 'used'
                                ? l10n.usedLabel
                                : l10n.spoiledLabel,
                      ),
                      selected: _reason == reason,
                      onSelected: (_) {
                        setState(() => _reason = reason);
                        _load();
                      },
                    ),
                ],
              ),
            ),
            if (_summary != null) _buildSummary(context, l10n, _summary!),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(padding: const EdgeInsets.all(16), child: Text(l10n.historyLoadError('$_error')))
            else if (_entries.isEmpty)
              EmptyState(icon: Icons.history, message: l10n.historyEmpty)
            else
              ..._buildGroupedEntries(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, AppLocalizations l10n, ConsumptionSummary summary) {
    // Values are plain numbers, not currency -- this app has no currency
    // setting (#324), the same reason the stock overview's total is unformatted.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.historyUsedSummary(summary.usedEntries, formatAmount(summary.usedValue))),
          Text(
            l10n.historySpoiledSummary(summary.spoiledEntries, formatAmount(summary.spoiledValue)),
            style: TextStyle(color: statusColor('expired')),
          ),
        ],
      ),
    );
  }

  /// Newest first, with a header per calendar day -- the log arrives already
  /// sorted that way from the API, so this only has to notice the breaks.
  List<Widget> _buildGroupedEntries(BuildContext context, AppLocalizations l10n) {
    final widgets = <Widget>[];
    DateTime? currentDay;
    for (final entry in _entries) {
      final local = entry.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (currentDay != day) {
        currentDay = day;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              day.toIso8601String().split('T').first,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      final spoiled = entry.reason == 'spoiled';
      widgets.add(
        ListTile(
          leading: Icon(
            spoiled ? Icons.delete_outline : Icons.check_circle_outline,
            color: spoiled ? statusColor('expired') : statusColor('ok'),
          ),
          title: Text(entry.productName),
          subtitle: Text(
            [
              formatAmount(entry.amount),
              if (entry.quantityUnit != null) entry.quantityUnit!,
            ].join(' '),
          ),
          trailing: Text(spoiled ? l10n.spoiledLabel : l10n.usedLabel),
        ),
      );
    }
    return widgets;
  }
}
