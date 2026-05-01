// 루트 위젯 — 테마·go_router 등록
import 'package:flutter/material.dart';

import 'core/constants/app_theme.dart';
import 'router/app_router.dart';

/// Vega 루트 앱
class VegaApp extends StatelessWidget {
  /// 기본 생성자
  const VegaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vega',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.config,
    );
  }
}
