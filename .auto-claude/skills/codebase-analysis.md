---
name: codebase-analysis
stages: [spec, plan]
description: 코드 분석 시 반드시 확인해야 할 체크리스트
---

# 코드 분석 체크리스트

## 수정 전 필수 확인
1. 호출처 추적 — 수정 대상 함수/프로퍼티를 사용하는 모든 곳 파악
2. 데이터 소스 확인 — 상태값이 어디서 오는지
3. 상태 관리 경로 — 값이 변경되면 어떤 UI/로직에 영향?
4. 저장/로드 경로 — Codable이면 기존 JSON과 호환되는지

## 위험 신호
- Codable 모델의 필드 추가/삭제/변경
- enum case 추가/삭제 (switch exhaustive 검사)
- 접근 제어 변경 (private → internal/public)
- 비동기 코드의 actor 격리 변경