import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_application/core/display/moyue_code_theme_registry.dart';
import 'package:moyue_application/core/display/moyue_color_contrast.dart';
import 'package:moyue_application/core/display/moyue_markdown_style.dart';
import 'package:moyue_application/core/display/moyue_markdown_theme_registry.dart';

void main() {
  test('所有阅读配色在亮暗模式下都满足正文可读性下限', () {
    for (final brightness in Brightness.values) {
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D7967),
        brightness: brightness,
      );
      for (final theme in MoyueMarkdownThemeRegistry.themes) {
        final palette = theme.palette(colors);
        expect(
          moyueContrastRatio(palette.foreground, palette.surface),
          greaterThanOrEqualTo(6.49),
          reason: '${theme.id} foreground on surface',
        );
        expect(
          moyueContrastRatio(palette.mutedForeground, palette.surface),
          greaterThanOrEqualTo(4.49),
          reason: '${theme.id} muted text on surface',
        );
        expect(
          moyueContrastRatio(
            palette.mutedForeground,
            palette.blockquoteSurface,
          ),
          greaterThanOrEqualTo(4.49),
          reason: '${theme.id} quote text',
        );
        expect(
          moyueContrastRatio(palette.heading, palette.tableHeaderSurface),
          greaterThanOrEqualTo(6.49),
          reason: '${theme.id} table heading',
        );
        expect(
          moyueContrastRatio(
            palette.inlineCodeForeground!,
            palette.inlineCodeSurface,
          ),
          greaterThanOrEqualTo(4.49),
          reason: '${theme.id} inline code',
        );
        expect(
          moyueContrastRatio(palette.link, palette.surface),
          greaterThanOrEqualTo(4.49),
          reason: '${theme.id} link',
        );
      }
    }
  });

  test('所有代码高亮主题与所有阅读配色组合均保持 Token 清晰', () {
    for (final brightness in Brightness.values) {
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6D7967),
        brightness: brightness,
      );
      for (final readerTheme in MoyueMarkdownThemeRegistry.themes) {
        final reader = readerTheme.palette(colors);
        for (final codeTheme in MoyueCodeThemeRegistry.themes) {
          final block = normalizeMoyueCodeBlockPalette(
            source: codeTheme.palette(brightness),
            reader: reader,
          );
          expect(
            moyueContrastRatio(block.foreground, block.background),
            greaterThanOrEqualTo(6.99),
            reason: '${readerTheme.id} + ${codeTheme.id} root',
          );
          expect(
            moyueContrastRatio(block.mutedForeground, block.headerBackground),
            greaterThanOrEqualTo(4.49),
            reason: '${readerTheme.id} + ${codeTheme.id} header',
          );
          for (final entry in block.syntaxStyles.entries) {
            final tokenBackground =
                entry.value.backgroundColor ?? block.background;
            final tokenForeground = entry.value.color ?? block.foreground;
            expect(
              moyueContrastRatio(tokenForeground, tokenBackground),
              greaterThanOrEqualTo(4.49),
              reason: '${readerTheme.id} + ${codeTheme.id} token ${entry.key}',
            );
          }
        }
      }
    }
  });
}
