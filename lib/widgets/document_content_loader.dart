import 'package:flutter/material.dart';
import 'package:moyue_application/core/i18n/moyue_i18n.dart';
import 'package:moyue_application/core/navigation/moyue_page_route.dart';
import 'package:moyue_application/models/reading_document.dart';
import 'package:moyue_application/services/moyue_storage_service.dart';
import 'package:moyue_application/widgets/floating_document_header.dart';

/// Read only the selected document. Never mount an editor with unloaded text.
class DocumentContentLoader extends StatefulWidget {
  const DocumentContentLoader({
    required this.document,
    required this.builder,
    super.key,
  });
  final ReadingDocument document;
  final Widget Function(ReadingDocument document) builder;

  @override
  State<DocumentContentLoader> createState() => _DocumentContentLoaderState();
}

class _DocumentContentLoaderState extends State<DocumentContentLoader> {
  late Future<ReadingDocument> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = MoyueStorageService.instance.readDocument(widget.document);

  @override
  void didUpdateWidget(covariant DocumentContentLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ReadingDocument>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        return widget.builder(snapshot.data!);
      }
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: FloatingDocumentHeader(
                  title: widget.document.title,
                  onBack: () => moyuePopCurrentRoute(context),
                  actionIcon: Icons.refresh_rounded,
                  actionLabel: MaterialLocalizations.of(context)
                      .refreshIndicatorSemanticLabel,
                  onAction: snapshot.hasError ? () => setState(_load) : null,
                ),
              ),
              Expanded(
                child: Center(
                  child: snapshot.hasError
                      ? Text(context.l10n.documentReadFailed)
                      : const CircularProgressIndicator.adaptive(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
