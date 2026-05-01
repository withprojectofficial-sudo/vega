import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vega/app.dart';

void main() {
  testWidgets('VegaApp 빌드 스모크 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VegaApp()));
    expect(find.text('지식 검색'), findsOneWidget);
  });
}
