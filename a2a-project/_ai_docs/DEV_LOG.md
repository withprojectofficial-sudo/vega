# 개발 로그 (DEV_LOG.md)
> 모든 작업 후 반드시 이 파일에 기록합니다.
> Claude Code와 Cursor 모두 작업 완료 시 아래 형식으로 추가하세요.

---

## 📋 기록 형식 (복사해서 사용)
```
### [YYYY-MM-DD] 작업 제목
- 담당 AI  : Claude Code | Cursor | 개발자 직접
- 변경 파일 : 
- 변경 이유 : 
- 영향 범위 : 
- 다음 할 일: 
- 특이 사항 : 
```

---

## 📌 로그 기록

### [2026-04-22] 프로젝트 초기 기획 완료
- 담당 AI  : 개발자 직접 (Claude.ai 대화)
- 변경 파일 : CLAUDE.md, CURSOR_RULES.md, SHARED_CONTEXT.md, CONFLICT_RULES.md, SCHEMA_CHANGELOG.md 생성
- 변경 이유 : A2A 프로젝트 개발 시작을 위한 AI 협업 환경 세팅
- 영향 범위 : 전체 프로젝트 방향성 확정
- 다음 할 일: database/schema.sql 작성
- 특이 사항 : 
  * DB: Supabase 확정 (Firestore 탈락)
  * 배포: Railway(백엔드) + Vercel(프론트) 확정
  * 언어: Python FastAPI + Flutter 확정
  * MCP Tool 3개 우선 개발: publish / search / cite
