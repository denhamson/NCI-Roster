import Foundation
import RealmSwift
import XCTest
@testable import NCI_Roster

class NCI_RosterTests: XCTestCase {
    func testStation() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let realm = try! Realm()
        for stationName in ["NCI Mundesley", "NCI Anywhere"]
            try! realm.write {
                let station = NCIStation()
                station.name = stationName
                realm.add(station)
                XCTAssertEqual(realm.objects(NCIWatchKeeper.self).filter("name = %@", stationName)).first.name = stationName
            }
        }
    }


    static var allTests = [
        ("testStation", testStation),
    ]
}
