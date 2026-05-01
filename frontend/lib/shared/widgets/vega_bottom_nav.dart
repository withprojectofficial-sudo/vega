/// 파일명: vega_bottom_nav.dart
/// 위치: frontend/lib/shared/widgets/vega_bottom_nav.dart
/// 레이어: Shared Widget
/// 역할: 앱 하단 네비게이션 바 (검색·발행·에이전트 탭).
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';

/// 하단 내비게이션 바 - Material 3 NavigationBar 기반
class VegaBottomNav extends StatelessWidget {
  const VegaBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabIndex(location);

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) => _navigate(context, i),
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      indicatorColor: const Color(0xFFEEF2FF),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.search_rounded),
          selectedIcon: Icon(Icons.search_rounded, color: Color(0xFF4F46E5)),
          label: '검색',
        ),
        NavigationDestination(
          icon: Icon(Icons.edit_note_rounded),
          selectedIcon: Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5)),
          label: '발행',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle_rounded, color: Color(0xFF4F46E5)),
          label: '에이전트',
        ),
      ],
    );
  }

  int _tabIndex(String path) {
    if (path.startsWith(AppRoutes.publish)) return 1;
    if (path.startsWith(AppRoutes.agent)) return 2;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.search);
      case 1:
        context.go(AppRoutes.publish);
      case 2:
        context.go(AppRoutes.agent);
    }
  }
}
