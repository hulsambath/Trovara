part of 'main_view.dart';

class _MainContent extends StatefulWidget {
  const _MainContent(this.viewModel);

  final MainViewModel viewModel;

  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> {
  int _currentIndex = 0;
  late PageController _pageController;

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex && index == 0) {
      widget.viewModel.onTabTap(context, index);
    } else if (index != _currentIndex) {
      _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
          Positioned.fill(
            bottom: isKeyboardVisible ? 0 : kToolbarHeight,
            child: PageView(controller: _pageController, onPageChanged: _onPageChanged, children: _pages),
          ),
          const Positioned(bottom: 0, left: 0, right: 0, child: ConnectivityStatus()),
          Positioned(
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
