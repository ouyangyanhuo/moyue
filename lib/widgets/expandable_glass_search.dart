import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ExpandableGlassSearch extends StatefulWidget {
  const ExpandableGlassSearch({
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<ExpandableGlassSearch> createState() => _ExpandableGlassSearchState();
}

class _ExpandableGlassSearchState extends State<ExpandableGlassSearch> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _close() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.unfocus();
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: _expanded
          ? SizedBox(
              key: const ValueKey('expanded-search'),
              width: MediaQuery.sizeOf(context).width.clamp(0, 268),
              child: GlassSearchBar(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: widget.hintText,
                onChanged: widget.onChanged,
                onCancel: _close,
                showsCancelButton: true,
                useOwnLayer: true,
                height: 46,
              ),
            )
          : GlassIconButton(
              key: const ValueKey('round-search-button'),
              icon: const Icon(Icons.search_rounded),
              onPressed: _open,
              semanticLabel: '搜索',
              size: 46,
              glowColor: Colors.transparent,
              useOwnLayer: true,
            ),
    );
  }
}
