import XCTest

/// Walks the whole module: /plans → leg-day → strength → cardio → review,
/// covering the acceptance criteria that depend on real interaction.
final class WorkoutFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(route: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        if let route {
            app.launchArguments += ["-route", route]
        }
        app.launch()
        return app
    }

    // MARK: - Routing

    func testFullRouteWalkthrough() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["训练计划库"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["高脚杯深蹲"].exists)

        app.buttons["查看计划"].tap()
        XCTAssertTrue(app.staticTexts["练腿日计划"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["膝盖记忆"].exists)
        XCTAssertTrue(app.staticTexts["建议重量 12 kg"].exists)

        // The third tone is 务实, never 严肃.
        XCTAssertTrue(app.buttons["务实"].exists)
        XCTAssertFalse(app.buttons["严肃"].exists)

        app.buttons["开始陪练"].tap()
        XCTAssertTrue(app.staticTexts["力量陪练"].waitForExistence(timeout: 3))
    }

    // MARK: - Voice UI states and the knee adjustment

    func testVoiceTurnsAdjustPrescription() {
        let app = launch(route: "/workout/strength")

        XCTAssertTrue(app.staticTexts["准备好了吗？"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["12 kg · 12 次"].exists)

        // Turn 1: "开始"
        app.buttons["开始语音"].tap()
        XCTAssertTrue(app.staticTexts["在听"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["开始"].waitForExistence(timeout: 6))
        XCTAssertTrue(
            app.staticTexts["膝盖朝脚尖方向，髋部向后坐。"].waitForExistence(timeout: 6)
        )

        // Turn 2: the knee complaint rewrites the next set.
        app.buttons["开始语音"].waitAndTap()
        XCTAssertTrue(app.staticTexts["膝盖有点紧。"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts["下一组降到 10 kg。仍然不适就改箱式深蹲。"]
                .waitForExistence(timeout: 8)
        )

        // Requirement: the knee memory changes the live prescription.
        XCTAssertTrue(app.staticTexts["10 kg · 12 次"].waitForExistence(timeout: 3))

        // No heart rate anywhere on the coaching screen.
        XCTAssertFalse(app.staticTexts["心率"].exists)
    }

    // MARK: - Sets, rest timer, and the hand-off to cardio then review

    func testStrengthCompletionThroughReview() {
        let app = launch(route: "/workout/strength")
        XCTAssertTrue(app.staticTexts["第 1 / 4 组"].waitForExistence(timeout: 6))

        // Report the knee once so the review reflects it.
        app.buttons["开始语音"].tap()
        XCTAssertTrue(app.staticTexts["开始"].waitForExistence(timeout: 8))
        app.buttons["开始语音"].waitAndTap()
        XCTAssertTrue(app.staticTexts["10 kg · 12 次"].waitForExistence(timeout: 10))

        for set in 1...4 {
            XCTAssertTrue(
                app.staticTexts["第 \(set) / 4 组"].waitForExistence(timeout: 6),
                "expected to be on set \(set)"
            )
            app.buttons["完成这组"].waitAndTap()

            if set < 4 {
                // Rest countdown is live; skip it rather than waiting 45s.
                XCTAssertTrue(app.staticTexts["休息"].waitForExistence(timeout: 3))
                app.buttons["跳过"].waitAndTap()
            }
        }

        let toCardio = app.buttons["力量部分完成，进入有氧"]
        XCTAssertTrue(toCardio.waitForExistence(timeout: 5))
        toCardio.tap()

        // Cardio
        XCTAssertTrue(app.staticTexts["跑步机快走"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6.0 km/h · 20 分钟"].exists)
        XCTAssertTrue(app.staticTexts["现在进入有氧阶段。"].waitForExistence(timeout: 6))

        app.buttons["完成有氧"].waitAndTap()
        let toReview = app.buttons["有氧完成，查看复盘"]
        XCTAssertTrue(toReview.waitForExistence(timeout: 5))
        toReview.tap()

        // Review
        XCTAssertTrue(app.staticTexts["今天完成了"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AI 记忆更新"].exists)
        XCTAssertTrue(
            app.staticTexts["右膝今天轻微紧张。下次台阶上步先调整为 2 组，并在深蹲前增加膝关节热身。"]
                .exists,
            "the knee report must drive the memory update"
        )
        XCTAssertTrue(app.staticTexts["90 分钟"].exists)
        XCTAssertTrue(app.staticTexts["100%"].exists)
        XCTAssertTrue(app.staticTexts["1 次"].exists)

        // No invented calories.
        XCTAssertFalse(app.staticTexts["消耗"].exists)

        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["训练计划库"].waitForExistence(timeout: 5))
    }

    // MARK: - Input mode switching

    func testTextModeSendsMessage() {
        let app = launch(route: "/workout/strength")
        XCTAssertTrue(app.staticTexts["准备好了吗？"].waitForExistence(timeout: 6))

        app.buttons["切换到文字输入"].tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("开始")
        app.keyboards.buttons["send"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts["膝盖朝脚尖方向，髋部向后坐。"].waitForExistence(timeout: 8)
        )

        app.buttons["切换到语音输入"].tap()
        XCTAssertTrue(app.buttons["开始语音"].waitForExistence(timeout: 3))
    }
}

private extension XCUIElement {
    /// The mic is briefly busy while the coach replies; wait it out.
    func waitAndTap(timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists && isHittable {
                tap()
                return
            }
            _ = XCUIApplication().wait(for: .runningForeground, timeout: 0.3)
        }
        XCTFail("element never became tappable: \(self)")
    }
}
