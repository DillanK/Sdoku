---
name: swift-safety-patterns
stages: [develop]
description: 반드시 지켜야 할 Swift 안전 패턴
---

# Swift 안전 패턴

## Codable 역호환
모든 Codable 모델에 새 필드 추가 시:
```swift
// 올바른 패턴
self.newField = try container.decodeIfPresent(String.self, forKey: .newField) ?? "기본값"
// 금지 — 기존 저장 데이터 로딩 실패
self.newField = try container.decode(String.self, forKey: .newField)
```

## @MainActor 격리
UI 상태를 변경하는 코드는 반드시 @MainActor에서 실행.

## Task에서 weak self
```swift
Task { [weak self] in
    guard let self else { return }
    await self.performWork()
}
```

## CheckedContinuation
반드시 모든 경로에서 한 번만 resume.

## features 배열 인덱스
firstIndex로 얻은 idx는 짧은 범위에서만 사용. 장기 보관 금지.