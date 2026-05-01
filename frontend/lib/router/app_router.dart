/// 파일명: app_router.dart
/// 위치: frontend/lib/router/app_router.dart
/// 레이어: Router (go_router 설정)
/// 역할: ShellRoute로 하단 네비게이션 바를 공유하고, 상세 화면은 Shell 바깥에 배치한다.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_routes.dart';
import '../pages/agent/agent_page.dart';
import '../pages/detail/detail_page.dart';
import '../pages/publish/publish_page.dart';
import '../pages/search/search_page.dart';
import '../shared/widgets/vega_bottom_nav.dart';

/// Vega 라우팅 설정
abstract final class AppRouter {
  static final GoRouter config = GoRouter(
    initialLocation: AppRoutes.search,
    routes: <RouteBase>[
      // 하단 네비게이션 Shell (검색·발행·에이전트)
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return _MainShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.search,
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.publish,
            name: 'publish',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PublishPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.agent,
            name: 'agent',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AgentPage(),
            ),
          ),
        ],
      ),

      // 지식 상세 — Shell 바깥에 배치하여 하단 네비 숨김
      GoRoute(
        path: '${AppRoutes.knowledgeDetail}/:id',
        name: 'knowledgeDetail',
        builder: (BuildContext context, GoRouterState state) {
          final String id = state.pathParameters['id'] ?? '';
          return DetailPage(knowledgeId: id);
        },
      ),
    ],
  );
}

/// 하단 네비게이션 바를 포함하는 Shell 래퍼
class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: const VegaBottomNav(),
      ),
    );
  }
}
