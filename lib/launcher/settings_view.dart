part of 'launcher.dart';

extension _LauncherSettingsView on _LauncherState {
  Widget _settings() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREFERENCES',
            style: sans.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: sub,
            ),
          ),
          Text('Make it yours.', style: serif),
          const SizedBox(height: 24),
          Text(
            'APPEARANCE',
            style: sans.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              color: sub,
            ),
          ),
          const SizedBox(height: 10),
          ...LauncherThemeMode.values.map(_themeModeOption),
          const SizedBox(height: 26),
          Text(
            'ACCENT COLOR',
            style: sans.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              color: sub,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose an accent color for the active appearance.',
            style: sans.copyWith(fontSize: 12, color: sub),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accentChoices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 78,
            ),
            itemBuilder: (context, index) {
              final choice = accentChoices[index];
              final selected = widget.accentIndex == index;
              return Material(
                color: selected ? accent.withValues(alpha: 0.08) : panel,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.selectAccent(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? accent : line,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: choice.seed,
                          child: Icon(
                            choice.icon,
                            size: 17,
                            color: choice.seed.computeLuminance() > .5
                                ? const Color(0xff20211e)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            choice.name,
                            style: sans.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected ? fg : sub,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: accent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: metricsSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.palette_outlined, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${accentChoices[widget.accentIndex].name} accent · ${widget.themeMode.label} palette',
                    style: sans.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: fg.withValues(alpha: 0.2)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Still Launcher · One intentional choice at a time.',
              style: GoogleFonts.newsreader(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: sub,
              ),
            ),
          ),
        ],
      );

  Widget _themeModeOption(LauncherThemeMode mode) {
    final selected = widget.themeMode == mode;
    final icon = switch (mode) {
      LauncherThemeMode.light => Icons.light_mode_outlined,
      LauncherThemeMode.dark => Icons.dark_mode_outlined,
      LauncherThemeMode.black => Icons.brightness_2_outlined,
    };
    final description = switch (mode) {
      LauncherThemeMode.light => 'Warm paper surfaces and light backgrounds.',
      LauncherThemeMode.dark => 'Soft charcoal surfaces with reduced glare.',
      LauncherThemeMode.black => 'Deep black surfaces for a fully dark look.',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.selectThemeMode(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accent : line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.15)
                        : line.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: selected ? accent : sub,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.label,
                        style: sans.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected ? fg : sub,
                        ),
                      ),
                      Text(
                        description,
                        style: sans.copyWith(fontSize: 11, color: sub),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: accent,
                    size: 20,
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: line, width: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
