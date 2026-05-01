# AI 간 충돌 방지 규칙 (CONFLICT_RULES.md)
> Claude Code와 Cursor가 동시에 작업할 때 충돌을 방지하기 위한 규칙입니다.
> 분쟁 발생 시 이 파일이 최우선 기준입니다.

---

## 📂 파일 소유권 (File Ownership)

| 파일 / 폴더 | 담당 | 규칙 |
|---|---|---|
| CLAUDE.md | Claude Code | Cursor 수정 금지 |
| .cursor/rules/ | Cursor | Claude Code 수정 금지 |
| backend/mcp_server.py | Claude Code | Cursor 수정 금지 |
| backend/utils/trust_score.py | Claude Code | Cursor 수정 금지 |
| backend/main.py | Claude Code | Cursor는 읽기만 가능 |
| backend/routers/ | 공동 | 수정 시 DEV_LOG 기록 필수 |
| database/schema.sql | 공동 | 변경 시 SCHEMA_CHANGELOG 기록 필수 |
| flutter_app/ | Cursor | Claude Code는 구조 제안만 가능 |
| _ai_docs/ | 공동 | 변경 시 날짜/이유 기록 필수 |

---

## ⚡ 충돌 발생 시 우선순위
```
1순위: _ai_docs/SHARED_CONTEXT.md  (단일 진실 공급원)
2순위: database/schema.sql         (DB가 기준)
3순위: 개발자 직접 판단
```

---

## 🔄 공동 작업 프로세스

### 라우터 파일 수정 시
1. DEV_LOG.md에 수정 의도 먼저 기록
2. 수정 진행
3. 완료 후 DEV_LOG.md 업데이트

### DB 스키마 변경 시
1. SCHEMA_CHANGELOG.md에 변경 이유 먼저 기록
2. schema.sql 수정
3. SHARED_CONTEXT.md의 테이블명/상태값 동기화

### 새 상수 추가 시
1. SHARED_CONTEXT.md에 먼저 정의
2. 그 후 코드에서 참조
3. 절대 코드에 먼저 하드코딩 후 나중에 옮기지 않음

---

## 🚨 절대 규칙
- 같은 파일을 Claude Code와 Cursor가 동시에 수정하지 않는다
- 상수값은 반드시 SHARED_CONTEXT.md에서 가져온다
- 소유권이 명확한 파일은 담당 AI만 수정한다
- 충돌 발생 시 개발자에게 즉시 보고 후 대기한다

---

## 💬 AI 간 커뮤니케이션 방법
코드 내 주석으로 메시지 전달:
```python
# [Claude Code → Cursor] 이 함수는 수정하지 마세요. trust_score 핵심 로직입니다.
# [Cursor → Claude Code] API 응답 형식이 변경되었습니다. SHARED_CONTEXT 확인 필요.
# [공동] 이 부분은 리팩토링 필요. 다음 스프린트에서 처리 예정.
```
