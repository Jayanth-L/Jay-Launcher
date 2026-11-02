import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_policy.dart';
import '../models/installed_app.dart';
import '../services/launcher_channel.dart';
import '../theme/accent_palette.dart';
import '../theme/launcher_theme.dart';
import '../theme/launcher_theme_mode.dart';

part 'launcher_state.dart';
part 'data_controller.dart';
part 'theme_styles.dart';
part 'main_view.dart';
part 'navigation.dart';
part 'home_view.dart';
part 'apps_view.dart';
part 'app_policy_dialog.dart';
part 'insights_view.dart';
part 'settings_view.dart';
part 'promise_dialog.dart';

class Launcher extends StatefulWidget {
  const Launcher({
    super.key,
    required this.displayName,
    required this.themeMode,
    required this.selectThemeMode,
    required this.accentIndex,
    required this.accentColor,
    required this.selectAccent,
  });
  final String displayName;
  final LauncherThemeMode themeMode;
  final ValueChanged<LauncherThemeMode> selectThemeMode;
  final int accentIndex;
  final Color accentColor;
  final ValueChanged<int> selectAccent;
  @override
  State<Launcher> createState() => _LauncherState();
}
