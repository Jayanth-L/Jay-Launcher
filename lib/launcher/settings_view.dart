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
                color: panel,
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
                                ? const Color(0xff30362b)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(choice.name,
                              style:
                                  sans.copyWith(fontWeight: FontWeight.w500)),
                        ),
                        if (selected) Icon(Icons.check_circle, color: accent),
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
            ),
            child: Row(
              children: [
                Icon(Icons.palette_outlined, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${accentChoices[widget.accentIndex].name} accent · ${widget.themeMode.label} palette',
                    style: sans.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
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
        color: panel,
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
                Icon(icon, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label,
                          style: sans.copyWith(fontWeight: FontWeight.w600)),
                      Text(description,
                          style: sans.copyWith(fontSize: 11, color: sub)),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
