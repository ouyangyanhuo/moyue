import 'dart:async';

import 'package:flutter/material.dart';

class ScrollingTitle extends StatefulWidget {
  const ScrollingTitle(
    this.text, {
    this.style,
    this.autoScroll = false,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final bool autoScroll;
  final TextAlign textAlign;

  @override
  State<ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<ScrollingTitle> {
  final ScrollController _controller = ScrollController();
  int _run = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoScroll) _startAfterLayout();
  }

  @override
  void didUpdateWidget(covariant ScrollingTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.autoScroll != widget.autoScroll) {
      _stop(reset: true);
      if (widget.autoScroll) _startAfterLayout();
    }
  }

  void _startAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    if (!_controller.hasClients || _controller.position.maxScrollExtent <= 0) {
      return;
    }
    final run = ++_run;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    while (mounted && run == _run && _controller.hasClients) {
      final extent = _controller.position.maxScrollExtent;
      if (extent <= 0) return;
      await _controller.animateTo(
        extent,
        duration: Duration(milliseconds: 900 + (extent * 18).round()),
        curve: Curves.linear,
      );
      if (!mounted || run != _run) return;
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await _controller.animateTo(
        0,
        duration: Duration(milliseconds: 700 + (extent * 12).round()),
        curve: Curves.easeOutCubic,
      );
      if (!mounted || run != _run) return;
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  void _stop({bool reset = false}) {
    _run++;
    if ((reset || !widget.autoScroll) && _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _run++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MouseRegion(
      onEnter: widget.autoScroll ? null : (_) => unawaited(_start()),
      onExit: widget.autoScroll ? null : (_) => _stop(reset: true),
      child: Listener(
        onPointerDown: widget.autoScroll ? null : (_) => unawaited(_start()),
        onPointerUp: widget.autoScroll ? null : (_) => _stop(reset: true),
        onPointerCancel: widget.autoScroll ? null : (_) => _stop(reset: true),
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              textAlign: widget.textAlign,
              style: widget.style,
            ),
          ),
        ),
      ),
    ),
  );
}
