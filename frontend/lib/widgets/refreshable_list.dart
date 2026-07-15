import 'package:flutter/material.dart';

import 'empty_state.dart';

/// The loading / error / empty / populated list shared by every screen
/// backed by a simple GET-and-list flow (Categories, Locations, Products).
/// Error and empty states are still wrapped in a scrollable [ListView], not
/// just a [Center], so pull-to-refresh keeps working with nothing to show.
class RefreshableList<T> extends StatelessWidget {
  final bool loading;
  final Object? error;
  final String Function(Object error) errorText;
  final IconData emptyIcon;
  final String emptyText;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRefresh;

  const RefreshableList({
    super.key,
    required this.loading,
    required this.error,
    required this.errorText,
    required this.emptyIcon,
    required this.emptyText,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final error = this.error;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: error != null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [Padding(padding: const EdgeInsets.all(16), child: Text(errorText(error)))],
            )
          : items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.45,
                      child: EmptyState(icon: emptyIcon, message: emptyText),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => itemBuilder(context, items[index]),
                ),
    );
  }
}
