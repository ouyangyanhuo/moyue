import 'dart:convert';

import 'package:moyue_application/services/reading_progress_service.dart';

/// CSS-pixel positions stay independent of Android/iOS device pixel ratios.
String buildWebViewReadingProgressScript({
  required String channel,
  required String layout,
  required ReadingProgress? initial,
}) =>
    '''
(() => {
  window.__moyueReadingCleanup?.();
  const channel = window[${jsonEncode(channel)}];
  if (!channel) return;
  const initial = ${initial?.encode() ?? 'null'};
  const sameLayout = initial && initial.layout === ${jsonEncode(layout)};
  let restoring = !!initial;
  let active = false;
  let timer = 0;
  let restoreTimer = 0;
  const deadline = performance.now() + 1500;
  const extent = () => Math.max(0,
    document.documentElement.scrollHeight - innerHeight,
    document.body ? document.body.scrollHeight - innerHeight : 0);
  const snapshot = () => restoring || !active ? null : ({
    offset: Math.max(0, scrollY), extent: extent()
  });
  const report = () => {
    clearTimeout(timer); timer = 0;
    if (restoring || !active) return;
    channel.postMessage(JSON.stringify(snapshot()));
  };
  const schedule = () => {
    if (!restoring) active = true;
    if (!timer) timer = setTimeout(report, 200);
  };
  const takeOver = () => {
    restoring = false; active = true;
    clearTimeout(restoreTimer);
  };
  const restore = () => {
    if (!restoring) return;
    const max = extent();
    const ratio = initial.extent > 0 ? initial.offset / initial.extent : 0;
    const target = Math.max(0, Math.min(max,
      sameLayout ? initial.offset : ratio * max));
    window.scrollTo({top: target, left: scrollX, behavior: 'instant'});
    if (performance.now() < deadline) {
      restoreTimer = setTimeout(restore, 120);
    } else {
      restoring = false;
    }
  };
  addEventListener('scroll', schedule, {passive: true});
  addEventListener('scrollend', report, {passive: true});
  addEventListener('pointerdown', takeOver, {passive: true});
  addEventListener('touchstart', takeOver, {passive: true});
  addEventListener('wheel', takeOver, {passive: true});
  addEventListener('keydown', takeOver);
  addEventListener('pagehide', report);
  const visibility = () => { if (document.hidden) report(); };
  document.addEventListener('visibilitychange', visibility);
  window.__moyueReadingReport = report;
  window.__moyueReadingSnapshot = snapshot;
  window.__moyueReadingTakeOver = takeOver;
  window.__moyueReadingCleanup = () => {
    clearTimeout(timer); clearTimeout(restoreTimer);
    removeEventListener('scroll', schedule);
    removeEventListener('scrollend', report);
    removeEventListener('pointerdown', takeOver);
    removeEventListener('touchstart', takeOver);
    removeEventListener('wheel', takeOver);
    removeEventListener('keydown', takeOver);
    removeEventListener('pagehide', report);
    document.removeEventListener('visibilitychange', visibility);
  };
  restore();
})();
''';
