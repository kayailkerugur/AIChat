import XCTest
@testable import AIChatSDK

final class SecureStoreTests: XCTestCase {
    @MainActor
    func test_inMemoryStoreSupportsSaveReadAndDelete() throws {
        let store = InMemorySecureStore()

        XCTAssertNil(try store.read(key: "provider.test.api-key"))

        try store.save("secret", forKey: "provider.test.api-key")
        XCTAssertEqual(try store.read(key: "provider.test.api-key"), "secret")

        try store.delete(key: "provider.test.api-key")
        XCTAssertNil(try store.read(key: "provider.test.api-key"))
    }

    @MainActor
    func test_deletingMissingKeyIsIdempotent() throws {
        let store = InMemorySecureStore()

        XCTAssertNoThrow(try store.delete(key: "missing"))
    }
}
