import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/quran_page.dart';
import 'pages/saved_page.dart';
import 'pages/settings_page.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const QuranApp());
}

class QuranApp extends StatefulWidget {
  const QuranApp({Key? key}) : super(key: key);

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  ThemeMode _themeMode = ThemeMode.light;
  double _quranFontSize = 26.0;

  @override
  void initState() {
    super.initState();
    _themeMode = StorageService.getThemeMode();
    _quranFontSize = StorageService.getQuranFontSize();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    StorageService.setThemeMode(_themeMode);
  }

  void _setQuranFontSize(double size) {
    setState(() {
      _quranFontSize = size;
    });
    StorageService.setQuranFontSize(size);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رفيق القرآن',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: AppShell(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeChanged: _toggleTheme,
        quranFontSize: _quranFontSize,
        onQuranFontSizeChanged: _setQuranFontSize,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.quranFontSize,
    required this.onQuranFontSizeChanged,
  }) : super(key: key);

  final bool isDarkMode;
  final VoidCallback onThemeChanged;
  final double quranFontSize;
  final ValueChanged<double> onQuranFontSizeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        onGoToQuran: () => setState(() => _index = 1),
      ),
      QuranPage(quranFontSize: widget.quranFontSize),
      const SavedPage(),
      SettingsPage(
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        quranFontSize: widget.quranFontSize,
        onQuranFontSizeChanged: widget.onQuranFontSizeChanged,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'المصحف',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: 'المحفوظات',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}