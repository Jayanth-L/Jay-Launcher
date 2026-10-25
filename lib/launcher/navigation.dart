part of 'launcher.dart';

extension _LauncherNavigation on _LauncherState {
  void _swipeToTab(int nextTab) {
    swipeAnimationTimer?.cancel();
    _updateState(() {
      tab = nextTab;
      fastPageExit = true;
    });
    swipeAnimationTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _updateState(() => fastPageExit = false);
    });
  }

  Widget _alphabetScroller() {
    final letters = installedApps
        .where((app) =>
            app.label.toLowerCase().contains(search.trim().toLowerCase()))
        .map((app) => app.label[0].toUpperCase())
        .toSet()
        .toList()
      ..sort();
    if (letters.isEmpty) return const SizedBox.shrink();

    void selectLetter(double dy, double height) {
      if (height <= 0) return;
      final index =
          (dy / height * letters.length).floor().clamp(0, letters.length - 1);
      final letter = letters[index];
      if (activeAlphabetLetter != letter) {
        _updateState(() => activeAlphabetLetter = letter);
        final sectionContext = appSectionKeys[letter]?.currentContext;
        if (sectionContext != null) {
          Scrollable.ensureVisible(
            sectionContext,
            duration: const Duration(milliseconds: 180),
            alignment: .08,
            curve: Curves.easeOut,
          );
        }
      }
      alphabetHintTimer?.cancel();
      alphabetHintTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _updateState(() => activeAlphabetLetter = null);
      });
    }

    return Positioned(
      right: 3,
      top: 82,
      bottom: 84,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              selectLetter(details.localPosition.dy, constraints.maxHeight),
          onVerticalDragStart: (details) =>
              selectLetter(details.localPosition.dy, constraints.maxHeight),
          onVerticalDragUpdate: (details) =>
              selectLetter(details.localPosition.dy, constraints.maxHeight),
          child: Container(
            width: 22,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: letters
                  .map((letter) {
                    final isSelected = activeAlphabetLetter == letter;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : sub,
                          fontSize: isSelected ? 10 : 9,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomNav() => Container(
        height: 76,
        decoration: BoxDecoration(
          color: (black
                  ? Colors.black
                  : dark
                      ? const Color(0xff121212)
                      : appPaper)
              .withValues(alpha: .96),
          border: Border(top: BorderSide(color: line.withValues(alpha: .8))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _nav(0, Icons.spa_outlined, 'Home'),
            _nav(1, Icons.grid_view_rounded, 'Apps'),
            _nav(2, Icons.bar_chart_rounded, 'Insights'),
          ],
        ),
      );
  Widget _nav(int index, IconData icon, String label) => InkWell(
        onTap: () {
          swipeAnimationTimer?.cancel();
          _updateState(() {
            tab = index;
            fastPageExit = false;
          });
        },
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: tab == index ? accent : inactive,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tab == index ? accent : inactive,
                ),
              ),
            ],
          ),
        ),
      );
}
