---
name: architecture-guide
stages: [spec, plan]
description: 아키텍처 가이드 — 서비스 구조, 의존성, 확장 패턴
---

# 아키텍처 가이드

## 핵심 구조
- AppState (@Observable) — 전역 상태
- FeatureWorkflowService — Lifecycle 워크플로우 관리, 큐잉, 병렬 제한
- LifecycleTaskRunner — 단일 Feature AI 실행
- LifecycleExecutionManager — Feature별 ClaudeService 인스턴스 관리
- ClaudeService — Claude CLI 프로세스 실행

## 새 기능 추가 패턴
1. 별도 서비스 파일로 생성
2. 기존 서비스 위에 레이어 (기존 수정 최소화)
3. AppState에서 참조만 추가
4. 단일 실행 경로 보장

## ClaudeService 사용
직접 생성 금지 → LifecycleExecutionManager.claudeService(for:) 사용

## 서비스命名 규칙
- 새 서비스는 `XXXFeatureService` 형태로 작성
- AppState에는 서비스 인스턴스만 추가하고, 직접 로직 구현 금지