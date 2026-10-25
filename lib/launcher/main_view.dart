part of 'launcher.dart';

extension _LauncherMainView on _LauncherState {
  Widget _buildLauncher(BuildContext context) => PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && tab != 0) _updateState(() => tab = 0);
        },
        child: Scaffold(
          backgroundColor: black
              ? Colors.black
              : dark
                  ? const Color(0xff101010)
                  : appCanvas,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  color: black
                      ? Colors.black
                      : dark
                          ? const Color(0xff121212)
                          : appPaper,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Hey, Jay',
                                  style: sans.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.2,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Settings',
                                      visualDensity: VisualDensity.compact,
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            dark ? panel : appCanvas,
                                      ),
                                      onPressed: () =>
                                          _updateState(() => tab = 3),
                                      icon: Icon(
                                        Icons.settings_outlined,
                                        size: 17,
                                        color: fg,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    CircleAvatar(
                                      radius: 4,
                                      backgroundColor: accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '82%',
                                      style: sans.copyWith(
                                        fontSize: 13,
                                        letterSpacing: .4,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity < -300 && tab < 2) {
                                  _swipeToTab(tab + 1);
                                }
                                if (velocity > 300 && tab > 0) {
                                  _swipeToTab(tab - 1);
                                }
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                reverseDuration: Duration(
                                  milliseconds: fastPageExit ? 120 : 500,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                transitionBuilder: (child, animation) =>
                                    AnimatedBuilder(
                                  animation: animation,
                                  child: child,
                                  builder: (context, child) {
                                    final fade = FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                    if (animation.status ==
                                        AnimationStatus.reverse) {
                                      return fade;
                                    }
                                    return SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0, .025),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: fade,
                                    );
                                  },
                                ),
                                child: tab == 1
                                    ? _apps()
                                    : SingleChildScrollView(
                                        key: ValueKey(tab),
                                        controller: scroll,
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          8,
                                          24,
                                          112,
                                        ),
                                        child: switch (tab) {
                                          0 => _home(),
                                          2 => _insights(),
                                          _ => _settings(),
                                        },
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                          left: 0, right: 0, bottom: 0, child: _bottomNav()),
                      if (tab == 1) _alphabetScroller(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void showBlocked(String name, {required String reason}) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss promise',
      barrierColor: const Color(0x6620211e),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _blockedSheet(name, reason),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .045),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
