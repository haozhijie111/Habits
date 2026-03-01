import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/practice_screen.dart';
import 'screens/drill_list_screen.dart';
import 'screens/record_screen.dart';
import 'screens/my_screen.dart';
import 'screens/flute_keyboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: FluteApp()));
}

/// 儿童友好配色
class KidColors {
  static const bg        = Color(0xFFFFF8F0);   // 暖白底
  static const primary   = Color(0xFFFF6B35);   // 活力橙
  static const secondary = Color(0xFF4ECDC4);   // 薄荷绿
  static const accent    = Color(0xFFFFE66D);   // 阳光黄
  static const purple    = Color(0xFFB388FF);   // 淡紫
  static const pink      = Color(0xFFFF8FAB);   // 粉红
  static const card      = Color(0xFFFFFFFF);   // 白卡片
  static const textDark  = Color(0xFF3D2C2C);   // 深棕文字
  static const textMid   = Color(0xFF8D6E63);   // 中棕
  static const textLight = Color(0xFFBCAAA4);   // 浅棕
  static const green     = Color(0xFF69D44B);   // 成功绿
  static const red       = Color(0xFFFF5252);   // 错误红
}

class FluteApp extends StatelessWidget {
  const FluteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小笛手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KidColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: KidColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: KidColors.bg,
          foregroundColor: KidColors.textDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: KidColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: KidColors.card,
          elevation: 3,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: KidColors.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ── 主导航壳 ──────────────────────────────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _pages = [
    PracticeScreen(),
    DrillListScreen(),
    FluteKeyboardScreen(),
    RecordScreen(),
    MyScreen(),
  ];

  void _onTabSelected(int i) {
    // 切换到"我的"tab 时自动刷新列表
    if (i == 4) {
      ref.invalidate(checkInRecordsProvider);
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        backgroundColor: KidColors.card,
        indicatorColor: KidColors.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Text('🎵', style: TextStyle(fontSize: 22)),
            label: '练习',
          ),
          NavigationDestination(
            icon: Text('🏋️', style: TextStyle(fontSize: 22)),
            label: '专项',
          ),
          NavigationDestination(
            icon: Text('🎹', style: TextStyle(fontSize: 22)),
            label: '玩笛子',
          ),
          NavigationDestination(
            icon: Text('📹', style: TextStyle(fontSize: 22)),
            label: '打卡',
          ),
          NavigationDestination(
            icon: Text('👤', style: TextStyle(fontSize: 22)),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
