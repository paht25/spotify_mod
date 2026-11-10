import XCTest

final class RuntimeUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchEnvironment.removeValue(forKey: "FIXTURE_PRESERVE_OPTION")
        app.launch()
        XCTAssertTrue(app.staticTexts["fixture.status"].waitForExistence(timeout: 15))
    }
    func state() -> [String: Any] {
        let json = app.staticTexts["fixture.status"].value as? String ?? "{}"
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }
    func number(_ key: String, _ state: [String: Any]) -> Double { state[key] as? Double ?? -999 }
    func wait(_ condition: @escaping ([String: Any]) -> Bool, timeout: TimeInterval = 10) {
        let done = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition(self.state()) }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: timeout), .completed, "State: \(state())")
    }
    func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        let data = try! JSONSerialization.data(withJSONObject: state(), options: [.prettyPrinted, .sortedKeys])
        let measurement = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        measurement.name = name + "-measurements"; measurement.lifetime = .keepAlways; add(measurement)
    }
    func ready() {
        wait { ($0["nativeController"] as? Bool) == true && ($0["nativeAccessory"] as? Bool) == true && ($0["tabs"] as? Int) == 4 }
    }
    func assertExpandedSizes() {
        wait {
            abs(self.number("navbarWidth", $0) - self.number("expectedWidth", $0)) < 0.6 &&
            abs(self.number("playerWidth", $0) - self.number("expectedWidth", $0)) < 0.6 &&
            abs(self.number("playerHeight", $0) - 56) < 0.6 &&
            abs(self.number("playerContainerHeight", $0) - 56) < 0.6 &&
            abs(self.number("playerContainerWidth", $0) - self.number("expectedWidth", $0)) < 0.6 &&
            abs(self.number("navbarY", $0) - self.number("playerY", $0) - 64) < 0.6 &&
            abs(self.number("navbarHeight", $0) - 62) < 0.6
        }
    }
    func point(_ x: Double, _ y: Double) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
    func testOriginalDimensionsSurviveLayout() {
        ready()
        for _ in 0..<3 { app.buttons["fixture.relayout"].tap() }
        assertExpandedSizes()
        capture("native-023-option-with-preserved-dimensions")
    }
    func testNativeNavbar023AddTabAndSymbolPicker() {
        ready()
        app.buttons["fixture.nativeNavbar"].tap()
        let addTab = app.cells.containing(.staticText, identifier: "Add a tab…").firstMatch
        XCTAssertTrue(addTab.waitForExistence(timeout: 10))
        addTab.tap()
        XCTAssertTrue(app.navigationBars["Add a Tab"].waitForExistence(timeout: 5))
        app.cells.containing(.staticText, identifier: "Link").firstMatch.tap()
        let liked = app.cells.containing(.staticText, identifier: "Liked Songs").firstMatch
        XCTAssertTrue(liked.waitForExistence(timeout: 5))
        liked.tap()
        app.cells.containing(.staticText, identifier: "Icon").firstMatch.tap()
        let symbols = app.segmentedControls.buttons["SF Symbols"]
        XCTAssertTrue(symbols.waitForExistence(timeout: 5))
        symbols.tap()
        app.tables.cells.firstMatch.tap()
        let selectedSymbol = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "SF Symbols ·")).firstMatch
        XCTAssertTrue(selectedSymbol.waitForExistence(timeout: 5))
        capture("native-navbar-023-symbol-draft")
        app.navigationBars["Add a Tab"].buttons["Add"].tap()
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Liked Songs").firstMatch.waitForExistence(timeout: 5))
        capture("native-navbar-023-added-tab")
    }
    func testAppearanceSwitchesStillWork() {
        ready()
        wait { ($0["binding"] as? Bool) == true }
        app.switches["toggle.fade"].tap()
        app.buttons["fixture.relayout"].tap()
        wait { self.number("fade", $0) == 0 }
        capture("native-navbar-fade-off")
        app.switches["toggle.fade"].tap()
        wait { self.number("fade", $0) > 0.9 }
        app.switches["toggle.profile"].tap()
        app.buttons["fixture.relayout"].tap()
        wait { self.number("photo", $0) == 0 }
        app.switches["toggle.profile"].tap()
        wait { self.number("photo", $0) > 0.9 }
    }
    func testWholeOptionPersistsAndAppliesAfterRestart() {
        ready()
        app.switches["toggle.inlinePlayer"].tap()
        wait { ($0["inlinePref"] as? Bool) == false && ($0["nativeController"] as? Bool) == true }
        app.terminate()
        app.launchEnvironment["FIXTURE_PRESERVE_OPTION"] = "1"
        app.launch()
        wait { ($0["inlineOption"] as? Bool) == false && ($0["nativeController"] as? Bool) == false }
        app.switches["toggle.inlinePlayer"].tap()
        wait { ($0["inlinePref"] as? Bool) == true }
        app.terminate(); app.launch()
        ready(); assertExpandedSizes()
    }
    func testNativeAccessoryMovesOnScrollAndReturns() {
        ready()
        wait { self.number("playerWidth", $0) > 100 }
        let bar = state()["bar"] as? String
        let accessory = state()["accessory"] as? String
        let list = app.tables["fixture.list"]
        list.swipeUp()
        wait { ($0["nativeInline"] as? Bool) == true }
        XCTAssertEqual(state()["bar"] as? String, bar)
        XCTAssertEqual(state()["accessory"] as? String, accessory)
        XCTAssertEqual(number("playerHeight", state()), 48, accuracy: 0.6)
        XCTAssertEqual(number("navbarHeight", state()), 48, accuracy: 0.6)
        capture("original-023-native-collapsed-accessory")
        for _ in 0..<3 {
            list.swipeDown()
            if state()["nativeInline"] as? Bool == false { break }
        }
        wait { ($0["nativeInline"] as? Bool) == false }
        assertExpandedSizes()
        XCTAssertEqual(state()["accessory"] as? String, accessory)
        capture("original-023-native-expanded-accessory")
    }
    func testNativePlayerAndTabControlsReachSpotify() {
        ready()
        wait { self.number("playerWidth", $0) > 100 }
        var s = state()
        point(number("playerX", s) + number("playerWidth", s) - 25,
              number("playerY", s) + number("playerHeight", s) / 2).tap()
        wait { self.number("toggleCount", $0) == 1 }
        s = state()
        point(number("playerX", s) + number("playerWidth", s) / 2,
              number("playerY", s) + number("playerHeight", s) / 2).tap()
        wait { self.number("openCount", $0) == 1 }
        s = state()
        let y = number("playerY", s) + number("playerHeight", s) / 2
        point(number("playerX", s) + number("playerWidth", s) * 0.7, y)
            .press(forDuration: 0.05, thenDragTo: point(number("playerX", s) + number("playerWidth", s) * 0.15, y))
        wait { self.number("nextCount", $0) == 1 }
        s = state()
        point(number("navbarX", s) + number("navbarWidth", s) - 31, number("navbarY", s) + 31).tap()
        wait { ($0["lastTab"] as? String) == "Create" }
    }
}
