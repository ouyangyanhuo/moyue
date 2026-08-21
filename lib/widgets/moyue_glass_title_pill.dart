import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/core/display/moyue_glass_style.dart';
import 'package:moyue_application/widgets/scrolling_title.dart';

/// 玻璃标题胶囊：文件夹页 / 阅读页 / 编辑页顶部的名称容器。
///
/// 与 [MoyueGlassIconButton] 走完全相同的 premium 折射管线
/// （LiquidGlass.withOwnLayer 纹理捕获 + 折射着色器），而不是
/// standard 档的普通高斯模糊观感；因此和按钮一样只能放置在
/// 滚动视口之外的静态浮层中。
class MoyueGlassTitlePill extends StatelessWidget {
  const MoyueGlassTitlePill({
    required this.title,
    this.width,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final String title;

  /// 固定宽度；不传时在父级约束内伸展（如浮动头部的 Expanded）。
  final double? width;

  /// 点击标题的回调（如重命名文件夹）。
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // 与按钮一致：省去 premium 反向裁剪的自定义阴影，
    // 只保留折射与高光，避免移动时留下暗色缓存圆。
    final settings = moyueGlassSettings(context)
        .copyWith(shadowElevation: 0, shadow: const []);
    final pill = GlassContainer(
      width: width,
      height: 42,
      useOwnLayer: true,
      quality: GlassQuality.premium,
      settings: settings,
      shape: const LiquidRoundedSuperellipse(borderRadius: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: ScrollingTitle(
        title,
        autoScroll: true,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(onTap: onTap, child: pill),
    );
  }
}
