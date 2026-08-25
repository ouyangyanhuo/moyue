import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:moyue_application/app/moyue_app.dart';
import 'package:moyue_application/core/display/display_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  final display = MoyueDisplayPreferences();
  await display.load();

  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: MoyueApp(display: display),
    ),
  );
}
