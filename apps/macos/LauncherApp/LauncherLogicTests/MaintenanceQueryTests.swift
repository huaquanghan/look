import XCTest
@testable import LauncherLogic

/// The two maintenance rows (Empty Trash, Clear Font Cache) pin themselves
/// above ordinary results, so a false positive outranks a real app - these
/// cover both the typo/prefix tolerance and the guard against that.
final class MaintenanceQueryTests: XCTestCase {
    func testEmptyTrashPhrasesMatch() {
        let queries = [
            "empty", "trash", "  Empty ", "TRASH",
            "empty trash", "clean trash", "clear trash",
            "  Empty   TRASH ", "empty t", "clean tr",
            "tarsh", "empyt",
        ]
        for query in queries {
            XCTAssertEqual(MaintenanceQuery.match(query), .emptyTrash, query)
        }
    }

    func testEmptyTrashLeavesOrdinarySearchesAlone() {
        let queries = [
            "", "clean", "emp", "tra", "trashes", "empty trash can",
            "clean trashed notes", "empty trashes", "empty x", "trash empty",
        ]
        for query in queries {
            XCTAssertNil(MaintenanceQuery.match(query), query)
        }
    }

    func testClearFontCachePhrasesMatch() {
        let queries = [
            "font cache", "clear font cache", "clean font cache",
            "reset fonts", "fonts cache", "clean font ca", "font cahce", "reset font",
        ]
        for query in queries {
            XCTAssertEqual(MaintenanceQuery.match(query), .clearFontCache, query)
        }
    }

    func testClearFontCacheLeavesOrdinarySearchesAlone() {
        let queries = [
            "font", "fonts", "cache", "clean font", "font book",
            "clear cache history",
        ]
        for query in queries {
            XCTAssertNil(MaintenanceQuery.match(query), query)
        }
    }
}
