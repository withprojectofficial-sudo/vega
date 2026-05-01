# A2A Project — Cursor 전용 규칙
> 이 파일은 Cursor AI가 코드 작성 시 반드시 준수해야 하는 규칙입니다.
> 작업 전 반드시 _ai_docs/SHARED_CONTEXT.md를 먼저 확인하세요.

---

## 🎯 Cursor의 역할
- Flutter 대시보드 UI/UX 개발 전담
- FastAPI 라우터 보조 작성 (trust_score 제외)
- 코드 자동완성 및 리팩토링 지원

---

## ✅ Cursor 전담 영역
- flutter_app/ 전체
- backend/routers/ 보조 작성
- 문서 정리 및 주석 보완

## 🚫 Cursor가 건드리면 안 되는 파일
| 파일 | 이유 |
|---|---|
| backend/mcp_server.py | Claude Code 전담 |
| backend/utils/trust_score.py | Claude Code 전담 |
| database/schema.sql | 변경 시 반드시 DEV_LOG 기록 후 협의 |
| _ai_docs/*.md | 양측 합의 후 수정 |

---

## 📱 Flutter 개발 규칙

### 폴더 구조
```
flutter_app/lib/
├── main.dart
├── screens/          # 페이지 단위 화면
│   ├── dashboard_screen.dart
│   ├── knowledge_screen.dart
│   └── transaction_screen.dart
├── widgets/          # 재사용 컴포넌트
├── services/         # API 호출 (여기서만)
│   └── api_service.dart
├── models/           # 데이터 모델
│   ├── knowledge.dart
│   └── transaction.dart
└── constants/        # 상수 정의
    └── app_constants.dart
```

### 상태관리
- 반드시 Riverpod 사용
- StatefulWidget 직접 사용 금지

### API 호출 규칙
- 모든 API 호출은 services/api_service.dart에서만
- 엔드포인트는 _ai_docs/SHARED_CONTEXT.md 기준

### UI 규칙
- Primary Color  : #1E3A5F
- Accent Color   : #2E6DA4
- Background     : #F5F8FC
- 폰트           : Noto Sans KR
- 모든 숫자(포인트, 점수)는 소수점 2자리까지 표시

---

## 📐 Dart 코딩 컨벤션
- 변수명/함수명: camelCase
- 클래스명: PascalCase
- 파일명: snake_case
- 주석: 한국어로 작성
- 함수: 단일 책임 원칙

---

## 🔌 API 연동 규칙
- Base URL: 환경변수에서 로드 (하드코딩 금지)
- 응답 형식: {"status": "ok|error", "data": {}}
- 에러 처리: 반드시 사용자에게 Toast 메시지 표시

---

## 🚨 절대 금지 사항
- API 엔드포인트 하드코딩 금지
- trust_score 계산 로직을 Flutter에서 구현 금지 (백엔드에서만)
- SHARED_CONTEXT.md 확인 없이 상수값 임의 정의 금지
- 작업 후 DEV_LOG.md 미기록 금지

---

## 💡 작업 완료 후 필수 행동
1. _ai_docs/DEV_LOG.md에 작업 내용 기록
2. 새로운 API 엔드포인트 추가 시 SHARED_CONTEXT.md 업데이트
