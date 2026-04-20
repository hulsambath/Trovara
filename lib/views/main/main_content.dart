part of 'main_view.dart';

class _MainContent extends StatefulWidget {
  const _MainContent(this.viewModel);

  final MainViewModel viewModel;

  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late final AnimationController _iosTabFadeController;

  final List<Widget> _pages = [
    const NotesView(),
    const ChatView(embedded: true),
    const InsightsView(),
    const SettingView(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _iosTabFadeController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _iosTabFadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) async {
    final fromIndex = _currentIndex;

    if (index == fromIndex && index == 0) {
      widget.viewModel.onTabTap(context, index);
      return;
    }

    if (index == fromIndex) return;

    // Update tab highlight immediately; PageView will catch up via animation/jump.
    setState(() {
      _currentIndex = index;
    });

    final distance = (index - fromIndex).abs();

    // On iOS, large index jumps (e.g. 0→3) look jarring when the PageView scrolls
    // through intermediate tabs. For those, do a quick fade + jump instead.
    if (Platform.isIOS && distance > 1) {
      try {
        await _iosTabFadeController.animateTo(
          0,
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
        );
        if (!mounted) return;
        _pageController.jumpToPage(index);
        await _iosTabFadeController.animateTo(
          1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        );
      } on TickerCanceled {
        // Ignore: happens if the widget is disposed mid-animation.
      }
      return;
    }

    final durationMs = (240 + (distance - 1) * 70).clamp(240, 420);
    try {
      await _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOutCubic,
      );
    } on TickerCanceled {
      // Ignore: can happen if another tab tap interrupts the animation.
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return _buildAndroid(context);
    }
    return _buildIOS(context);
  }

  Widget _buildAndroid(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        PageView(controller: _pageController, onPageChanged: _onPageChanged, children: _pages),
        const Positioned(bottom: 0, left: 0, right: 0, child: ConnectivityStatus()),
      ],
    ),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Notes'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Insights'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );

  Widget _buildIOS(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: 0,
            left: 0,
            right: 0,
            bottom: isKeyboardVisible ? 0 : kToolbarHeight,
            child: FadeTransition(
              opacity: _iosTabFadeController,
              child: PageView(controller: _pageController, onPageChanged: _onPageChanged, children: _pages),
            ),
          ),
          const Positioned(bottom: 0, left: 0, right: 0, child: ConnectivityStatus()),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            bottom: isKeyboardVisible ? -kToolbarHeight : 0,
            left: 0,
            right: 0,
            child: CNTabBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              items: const [
                CNTabBarItem(icon: CNSymbol('square.and.pencil'), label: 'Notes'),
                CNTabBarItem(icon: CNSymbol('bubble.left.and.bubble.right'), label: 'Chat'),
                CNTabBarItem(icon: CNSymbol('chart.bar'), label: 'Insights'),
                CNTabBarItem(icon: CNSymbol('gear'), label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
