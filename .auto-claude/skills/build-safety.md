---
name: build-safety
stages: [plan, develop]
description: 빌드 안전성을 유지하며 점진적으로 구현하는 전략
---

# 빌드 안전 전략

## 구현 순서 원칙
1. Model 먼저 — 새 struct/enum/protocol 정의
2. Service 다음 — 비즈니스 로직 구현
3. 기존 서비스 연결 — 호출 코드 추가
4. View 마지막 — UI 연결

## 안전한 제거 순서 (리팩토링/삭제 시)
1. 참조 제거 먼저 — 사용처에서 import/호출 제거
2. 빌드 확인
3. 파일 삭제

## SubTask 분할 기준
- 각 SubTask 완료 시점에 빌드가 성공해야 함
- 컴파일 에러를 유발하는 중간 상태 금지
- 의존성이 있는 변경은 같은 SubTask에 포함