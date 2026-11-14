import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The flat, warm-grey palette of the Minimal view. Screens and popups that
/// are not under the Minimal shell (dialogs, sheets) apply it themselves.
GymColors minimalColors(GymColors base) => base.copyWith(
      pageBg: const Color(0xFF0E0E0D),
      bg: const Color(0xFF141413),
      bgRaised: const Color(0xFF1B1B1A),
      bgRaised2: const Color(0xFF222221),
      border: const Color(0xFF2C2C2A),
      navBg: const Color(0xEE141413),
      text: const Color(0xFFE9E7E2),
      textSecondary: const Color(0xFF8D8A84),
      textTertiary: const Color(0xFF5F5D58),
      ember: const Color(0xFFC8A45F),
      emberDeep: const Color(0xFFA88647),
      onEmber: const Color(0xFF141413),
      emberSoft: const Color(0x35C8A45F),
      accent: const Color(0xFFC8A45F),
      accentSoft: const Color(0x35C8A45F),
      brass: const Color(0xFFC8A45F),
      sage: const Color(0xFFC8A45F),
      sageSoft: const Color(0x35C8A45F),
      mutedFill: const Color(0xFF222221),
      heatEmpty: const Color(0xFF222221),
    );
