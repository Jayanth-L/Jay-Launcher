part of 'launcher.dart';

extension _LauncherPromiseDialog on _LauncherState {
  Widget _blockedSheet(String name, String reason) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: line),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: alertSurface,
                      child: Icon(Icons.lock_outline, color: alertInk),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: panel),
                      icon: Icon(Icons.close, color: fg),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'A PROMISE TO YOURSELF',
                  style: sans.copyWith(
                    color: alertInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You wanted more time for the life that matters.',
                  style: GoogleFonts.newsreader(
                    color: fg,
                    fontSize: 30,
                    height: 1.1,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason == 'daily_limit'
                      ? 'You reached the daily limit you set for $name. Take a moment and return when your limit resets.'
                      : 'Your allowed hours for $name have ended for now. You can change this schedule any time in App limits.',
                  style: sans.copyWith(color: sub, fontSize: 14, height: 1.7),
                ),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: panel,
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '“I’m building a calmer life—one intentional choice at a time.”',
                    style: GoogleFonts.newsreader(
                      color: fg.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  reason == 'daily_limit'
                      ? 'Your daily limit resets at midnight.'
                      : 'Your app will be available again during your next allowed window.',
                  style: sans.copyWith(fontSize: 12, color: sub),
                ),
                const SizedBox(height: 19),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: actionInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Honor my promise',
                      style: sans.copyWith(
                        fontWeight: FontWeight.w600,
                        color: actionInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _dateLabel() {
    final d = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[d.weekday - 1].toUpperCase()}, ${months[d.month - 1].toUpperCase()} ${d.day}';
  }
}
