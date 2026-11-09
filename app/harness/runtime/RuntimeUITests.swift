import XCTest

final class RuntimeUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.staticTexts["fixture.status"].waitForExistence(timeout: 15))
    }
    func state() -> [String: Any] {
        let json = app.staticTexts["fixture.status"].value as? String ?? "{}"
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }
    func wait(_ condition: @escaping ([String: Any]) -> Bool, timeout: TimeInterval = 8) {
        let done = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition(self.state()) }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: timeout), .completed, "State: \(state())")
    }
    func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
    func testPlayerWidthSurvivesAutoLayout() {
        wait { ($0["native"] as? Bool) == true && ($0["tabs"] as? Int) == 4 }
        let bar = state()["bar"] as? String
        for _ in 0..<3 { app.buttons["fixture.relayout"].tap() }
        wait { ($0["widthError"] as? Double ?? 999) < 0.6 && ($0["glassError"] as? Double ?? 999) < 0.6 }
        XCTAssertEqual(state()["bar"] as? String, bar, "Original UITabBar must remain in place")
        capture("expanded-navbar-and-aligned-player")
    }
    func testRealAppearanceSwitchesAfterAccessoryReparenting() {
        wait { ($0["binding"] as? Bool) == true }
        app.switches["toggle.fade"].tap()
        wait { ($0["fade"] as? Double ?? 1) == 0 && ($0["hostFades"] as? Int) == 0 }
        app.buttons["fixture.relayout"].tap()
        wait { ($0["fade"] as? Double ?? 1) == 0 && ($0["hostFades"] as? Int) == 0 }
        capture("bottom-fade-off")
        app.switches["toggle.fade"].tap()
        wait { ($0["fade"] as? Double ?? 0) > 0.9 && ($0["hostFades"] as? Int ?? 0) > 0 }
        app.switches["toggle.profile"].tap()
        wait { ($0["photo"] as? Double ?? 1) == 0 }
        app.buttons["fixture.relayout"].tap()
        wait { ($0["photo"] as? Double ?? 1) == 0 }
        app.switches["toggle.profile"].tap()
        wait { ($0["photo"] as? Double ?? 0) > 0.9 }
    }
    func testUIKitCollapseFromActualDragAndReverse() {
        wait { ($0["native"] as? Bool) == true && ($0["motionTrace"] as? [[Double]] ?? []).count > 0 }
        let bar = state()["bar"] as? String
        let list = app.tables["fixture.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.swipeUp()
        wait { ($0["progress"] as? Double ?? 0) > 0.95 }
        XCTAssertEqual(state()["nativeInline"] as? Bool, true, "UIKit's real accessory must be minimized")
        capture("apple-music-style-collapsed-row")
        list.swipeDown()
        wait { ($0["progress"] as? Double ?? 1) < 0.05 }
        let trace = state()["motionTrace"] as? [[Double]] ?? []
        let data = try! JSONSerialization.data(withJSONObject: trace, options: [.prettyPrinted])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "native-motion-frame-trace"
        attachment.lifetime = .keepAlways
        add(attachment)
        var rising = 0, falling = 0, largestStep = 0.0
        for (a, b) in zip(trace, trace.dropFirst()) {
            let delta = b[1] - a[1]
            // A busy simulator can skip our sampling callbacks while Core Animation still
            // presents intermediate frames. Compare the change per 60 Hz interval.
            let elapsed = max(1.0 / 120.0, b[0] - a[0])
            largestStep = max(largestStep, abs(delta) * min(1, (1.0 / 60.0) / elapsed))
            if b[1] > 0.01 && b[1] < 0.99 {
                if delta > 0 { rising += 1 }
                if delta < 0 { falling += 1 }
            }
        }
        XCTAssertEqual(state()["compositorObserved"] as? Bool, true,
            "Player and tabs must both animate on the compositor, rather than redraw per tick")
        XCTAssertGreaterThanOrEqual(rising, 4, "Collapse must have intermediate presentation states")
        XCTAssertGreaterThanOrEqual(falling, 4, "Reverse must animate, rather than snap to expanded")
        XCTAssertLessThan(largestStep, 0.35, "Motion jumped in a single frame; inspect trace/video")
        let peak = trace.firstIndex(where: { $0[1] >= 0.999 }) ?? trace.count
        for (index, pair) in zip(trace, trace.dropFirst()).enumerated() {
            let delta = pair.1[1] - pair.0[1]
            if index < peak { XCTAssertGreaterThanOrEqual(delta, -0.002, "Collapse moved backwards") }
            else { XCTAssertLessThanOrEqual(delta, 0.002, "Expansion moved backwards") }
        }
        XCTAssertEqual(state()["bar"] as? String, bar)
        XCTAssertEqual(state()["tabs"] as? Int, 4)
        capture("original-navbar-restored-after-reverse-scroll")
    }
}
