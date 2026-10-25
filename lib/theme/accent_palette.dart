import 'package:flutter/material.dart';

class AccentChoice {
  const AccentChoice(this.name, this.seed, this.icon);

  final String name;
  final Color seed;
  final IconData icon;
}

const accentChoices = [
  AccentChoice('Sage', Color(0xff66715b), Icons.eco_outlined),
  AccentChoice('Ocean', Color(0xff4d7488), Icons.water_outlined),
  AccentChoice('Plum', Color(0xff79648a), Icons.local_florist_outlined),
  AccentChoice('Terracotta', Color(0xffa86651), Icons.wb_sunny_outlined),
  AccentChoice('Amber', Color(0xff94723e), Icons.light_mode_outlined),
];
