import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/widgets/moyue_glass_icon_button.dart';

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
              child: Row(
                children: [
                  Expanded(
                    child: GlassTextField.search(
                      controller: _controller,
                      focusNode: _focusNode,
                      placeholder: widget.hintText,
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      onChanged: _handleChanged,
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : const Icon(Icons.cancel_rounded, size: 18),
                      onSuffixTap: _controller.text.isEmpty ? null : _clear,
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      settings: moyueGlassSettings(context),
                      interactionBehavior: GlassInteractionBehavior.scaleOnly,
                      height: 46,
                    ),
                  ),
                  const SizedBox(width: 8),
                  MoyueGlassIconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _close,
                    semanticLabel: '关闭搜索',
                    size: 46,
                    settings: moyueGlassSettings(context),
                  ),
                ],
              ),
            )
          : MoyueGlassIconButton(
              key: const ValueKey('round-search-button'),
              icon: const Icon(Icons.search_rounded),
              onPressed: _open,
              semanticLabel: '搜索',
              size: 46,
              useOwnLayer: true,
              settings: moyueGlassSettings(context),
            ),
    );
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }
}
