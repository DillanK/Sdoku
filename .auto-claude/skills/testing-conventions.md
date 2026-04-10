---
name: testing-conventions
stages: [develop, plan]
description: 테스트 작성 규칙 — Swift Testing 프레임워크
---

# 테스트 작성 규칙

## 프레임워크
```swift
import Testing
@testable import AutoAI

@Suite("FeatureName Tests")
@MainActor
struct FeatureNameTests {
    @Test func someTest() {
        #expect(result == expected)
    }
}
```

## AppState 테스트 패턴
- AppState를 반드시 변수로 유지 (weak var 참조 해제 방지)
- 테스트마다 새 인스턴스 생성 (상태 오염 방지)
- projectPath = "" → 파일 I/O 비활성화

## 금지 사항
- projectPath = ""에서 deleteFeature 호출 기대 금지
- saveFeature() 후 즉시 디스크 검증 금지 (비동기 저장)
- LifecycleTaskRunner 테스트에 @MainActor 누락 금지