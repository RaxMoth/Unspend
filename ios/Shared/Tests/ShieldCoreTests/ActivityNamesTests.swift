import XCTest
@testable import ShieldCore

final class ActivityNamesTests: XCTestCase {
    func testNamesAreScopedPerProfile() {
        XCTAssertEqual(ActivityNames.schedule("abc"), "unspend.schedule.abc")
        XCTAssertEqual(ActivityNames.day("abc"), "unspend.day.abc")
        XCTAssertEqual(ActivityNames.store("abc"), "unspend.abc")
        XCTAssertEqual(ActivityNames.legacyLimit("abc"), "unspend.limit.abc")
    }

    func testTheRemovalLockStoreIsNotAProfileStore() {
        XCTAssertEqual(ActivityNames.removalLockStore, "unspend.guard")
        XCTAssertNil(ActivityNames.parse(ActivityNames.removalLockStore))
    }

    func testParseRecoversKindAndProfileId() {
        let schedule = ActivityNames.parse(ActivityNames.schedule("1731840000000_004217"))
        XCTAssertEqual(schedule?.kind, .schedule)
        XCTAssertEqual(schedule?.profileId, "1731840000000_004217")

        let day = ActivityNames.parse(ActivityNames.day("1731840000000_004217"))
        XCTAssertEqual(day?.kind, .day)
        XCTAssertEqual(day?.profileId, "1731840000000_004217")
    }

    func testProfileIdsContainingDotsSurvive() {
        XCTAssertEqual(ActivityNames.parse("unspend.schedule.a.b.c")?.profileId, "a.b.c")
    }

    func testUnknownNamesAreRejected() {
        XCTAssertNil(ActivityNames.parse("unspend.limit.abc"), "legacy monitors are not evaluated")
        XCTAssertNil(ActivityNames.parse("someone.else"))
        XCTAssertNil(ActivityNames.parse("unspend.schedule."))
        XCTAssertNil(ActivityNames.parse(""))
    }
}
