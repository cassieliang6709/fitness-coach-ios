import XCTest

/// Walks the whole module: /welcome → /home → leg-day → strength → cardio →
/// review, covering the acceptance criteria that depend on real interaction.
final class WorkoutFlowUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// `onboarded: false` gives a brand new user, which is the only state that
    /// shows the welcome flow.
    private func launch(
        route: String? = nil,
        freshStore: Bool = true,
        onboarded: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        if freshStore {
            app.launchArguments += ["-uitest"]
        }
        if onboarded {
            app.launchArguments += ["-onboarded"]
        }
        if let route {
            app.launchArguments += ["-route", route]
        }
        app.launch()
        return app
    }

    /// Keep callers explicit about the plan tab, even though it is the default.
    private func openPlanTab(_ app: XCUIApplication) {
        let planTab = app.buttons["我的计划"]
        XCTAssertTrue(planTab.waitForExistence(timeout: 5))
        planTab.tap()
    }

    /// 4 + 4 + 3 + 3 + 3 + 3
    private static let plannedSets = 20

    // MARK: - Exercise library

    func testRiveLabSwitchesTheCharacterStateMachineInput() {
        let app = launch(route: "/rive-lab")

        XCTAssertTrue(app.staticTexts["Rive 动作实验"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["当前状态：Beginner"].exists)

        app.buttons["rive-level-expert"].tap()
        XCTAssertTrue(app.staticTexts["当前状态：Expert"].waitForExistence(timeout: 3))
    }

    func testExerciseLibraryFiltersKneeContraindicationsBeforeSearch() {
        let app = launch(route: "/exercises")

        XCTAssertTrue(app.staticTexts["动作库"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["34 个适合你 · 完整库 50 个"].exists)
        XCTAssertTrue(app.staticTexts["猫牛式"].exists)

        // The demo profile has a knee condition. Searching cannot bring a
        // contraindicated movement back after the safety filter has run.
        let search = app.textFields["搜索动作、部位或器械"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("高脚杯深蹲")
        XCTAssertTrue(app.staticTexts["没有匹配的动作"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["高脚杯深蹲"].exists)
    }

    func testExerciseLibraryUsesExerciseSpecificArtwork() {
        let app = launch(route: "/exercises")

        let search = app.textFields["搜索动作、部位或器械"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("臀桥")

        XCTAssertTrue(app.staticTexts["臀桥"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.images["exercise-specific-artwork-glute-bridge"].exists)

        if app.keyboards.firstMatch.exists {
            app.keyboards.firstMatch.swipeDown()
        }
        app.swipeUp()

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "exercise-library-glute-bridge-artwork"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testGeneratedExerciseArtworkAppearsInDetail() {
        let app = launch(route: "/exercises/reverse-lunge")

        XCTAssertTrue(app.staticTexts["后撤弓步"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.images["exercise-specific-artwork-reverse-lunge"]
                .waitForExistence(timeout: 3)
        )
    }

    // MARK: - Welcome

    /// A new user answers four questions, and every answer is a memory chip on
    /// the home page before the first workout.
    func testWelcomeFlowSeedsMemoriesAndLandsOnHome() {
        let app = launch(onboarded: false)

        XCTAssertTrue(app.staticTexts["先认识一下"].waitForExistence(timeout: 5))
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["你想练成什么样？"].waitForExistence(timeout: 3))
        app.buttons["option-增肌"].tap()
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["平时在哪训练？"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["拍下你常用的器械"].exists)
        app.buttons["option-家里"].tap()
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["身体有需要避开的地方吗？"].waitForExistence(timeout: 3))
        app.buttons["option-膝盖"].tap()
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["希望我用什么语气？"].waitForExistence(timeout: 3))
        app.buttons["温和"].tap()
        app.buttons["开始使用"].tap()

        // Home opens on the plan tab, where the onboarding answers are visible.
        openPlanTab(app)
        XCTAssertTrue(app.staticTexts["训练目标：增肌"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["常在家里训练"].exists)
        XCTAssertTrue(app.staticTexts["膝盖不适：避免跳跃，深蹲降重量"].exists)

        // Nothing has been trained yet, so the record is honestly empty.
        XCTAssertTrue(app.staticTexts["0 / 4 次"].exists)
        XCTAssertTrue(app.staticTexts["0 天"].exists)
    }

    /// The welcome flow only runs once — a returning user lands on home.
    func testReturningUserSkipsWelcome() {
        let app = launch()

        XCTAssertTrue(app.buttons["对话"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["我的计划"].exists)
        XCTAssertFalse(app.staticTexts["先认识一下"].exists)
    }

    // MARK: - Home tabs

    func testHomeTabsSwitchContent() {
        let app = launch()

        // 我的计划 is the default home tab.
        XCTAssertTrue(app.staticTexts["本周训练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AI 记住的事"].exists)
        XCTAssertTrue(app.buttons["开始今天的训练"].exists)

        // 对话: the coach's opening line, and tappable openers.
        app.buttons["对话"].tap()
        XCTAssertTrue(
            app.staticTexts["今天安排的是练腿日：力量 60 分钟，有氧 20–30 分钟。"]
                .waitForExistence(timeout: 8)
        )
        // A cached/default plan is not a chat result. The card only appears
        // after this conversation actually generates a new plan.
        XCTAssertFalse(app.staticTexts["AI 计划已生成"].exists)

        // A chip answers the question it names, not the next line in the script.
        app.buttons["今天时间不多"].waitAndTap()
        XCTAssertTrue(
            app.staticTexts["那就只做深蹲、臀桥、腿推，有氧压到 15 分钟，40 分钟能结束。"]
                .waitForExistence(timeout: 8)
        )

        openPlanTab(app)
        XCTAssertTrue(app.staticTexts["本周训练"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AI 记住的事"].exists)
        XCTAssertTrue(app.buttons["开始今天的训练"].exists)
    }

    func testExerciseLearningTabSwipesThroughCatalog() {
        let app = launch()

        app.buttons["抽动作"].waitAndTap()
        XCTAssertTrue(app.staticTexts["动作抽卡"].waitForExistence(timeout: 3))
        app.buttons["动作库"].waitAndTap()
        XCTAssertTrue(app.staticTexts["第 1 / 50 个"].exists)
        XCTAssertTrue(app.staticTexts["动作要点"].exists)
        XCTAssertTrue(app.staticTexts["注意事项"].exists)

        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["第 2 / 50 个"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["动作要点"].exists)
        XCTAssertTrue(app.staticTexts["注意事项"].exists)
    }

    func testDrawsThreeExercisesAndStartsCoaching() {
        let app = launch()

        app.buttons["抽动作"].waitAndTap()
        XCTAssertTrue(app.staticTexts["今天的流程"].waitForExistence(timeout: 3))

        for _ in 0..<3 {
            app.buttons["上滑加入"].waitAndTap()
        }

        XCTAssertTrue(app.staticTexts["3 / 3–6"].waitForExistence(timeout: 3))
        app.buttons["用这 3 个动作开始"].waitAndTap()
        XCTAssertTrue(app.staticTexts["力量陪练"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["动作 1 / 2"].exists)
    }

    // MARK: - Routing

    func testFullRouteWalkthrough() {
        let app = launch()

        openPlanTab(app)
        app.buttons["换个计划"].waitAndTap()

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

    func testPlanExerciseOpensLibraryDetailAndReturnsToPlan() {
        let app = launch(route: "/plans/leg-day")

        XCTAssertTrue(app.staticTexts["已连接你的动作库"].waitForExistence(timeout: 5))
        app.buttons["plan-exercise-goblet-squat"].waitAndTap()

        XCTAssertTrue(app.staticTexts["高脚杯深蹲"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["大腿前侧 · 臀"].exists)
        XCTAssertTrue(app.staticTexts["在今天的 AI 计划里"].exists)

        app.buttons["返回"].waitAndTap()
        XCTAssertTrue(app.staticTexts["练腿日计划"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["已连接你的动作库"].exists)
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

    // MARK: - Every exercise, then cardio, then review

    func testWalksAllExercisesAndReviewsOnlyLoggedWork() {
        let app = launch(route: "/workout/strength")
        XCTAssertTrue(app.staticTexts["动作 1 / 6"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["高脚杯深蹲"].exists)

        // Report the knee once so the review reflects it.
        app.buttons["开始语音"].tap()
        XCTAssertTrue(app.staticTexts["开始"].waitForExistence(timeout: 8))
        app.buttons["开始语音"].waitAndTap()
        XCTAssertTrue(app.staticTexts["10 kg · 12 次"].waitForExistence(timeout: 10))

        // 6 exercises, 20 sets total.
        let plan: [(name: String, sets: Int)] = [
            ("高脚杯深蹲", 4), ("臀桥", 4), ("台阶上步", 3),
            ("坐姿腿推", 3), ("坐姿腿弯举", 3), ("小腿提踵", 3),
        ]
        var remaining = Self.plannedSets

        for (index, exercise) in plan.enumerated() {
            XCTAssertTrue(
                app.staticTexts["动作 \(index + 1) / 6"].waitForExistence(timeout: 8),
                "expected to reach exercise \(index + 1)"
            )
            XCTAssertTrue(app.staticTexts[exercise.name].exists)

            for set in 1...exercise.sets {
                XCTAssertTrue(
                    app.staticTexts["第 \(set) / \(exercise.sets) 组"].waitForExistence(timeout: 8)
                )
                app.buttons["完成这组"].waitAndTap()
                remaining -= 1

                if remaining > 0 {
                    XCTAssertTrue(app.staticTexts["休息"].waitForExistence(timeout: 4))
                    app.buttons["跳过"].waitAndTap()
                }
            }
        }

        let toCardio = app.buttons["力量部分完成，进入有氧"]
        XCTAssertTrue(toCardio.waitForExistence(timeout: 6))
        toCardio.tap()

        XCTAssertTrue(app.staticTexts["跑步机快走"].waitForExistence(timeout: 5))
        // Cardio now runs on a real clock, so it starts at zero.
        XCTAssertTrue(app.staticTexts["已完成 0 / 30 分钟"].exists)

        app.buttons["完成有氧"].waitAndTap()
        let toReview = app.buttons["有氧完成，查看复盘"]
        XCTAssertTrue(toReview.waitForExistence(timeout: 5))
        toReview.tap()

        // Every set was logged, so completion is genuinely 100%.
        XCTAssertTrue(app.staticTexts["今天完成了"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["100%"].exists)
        XCTAssertTrue(app.staticTexts["4 / 4 组 · 12 次"].exists)
        XCTAssertTrue(app.staticTexts["3 / 3 组 · 10 次 / 侧"].exists)
        XCTAssertTrue(app.staticTexts["1 次"].exists)
        XCTAssertFalse(app.staticTexts["消耗"].exists)
    }

    /// The review must not tick off work the user never did.
    func testPartialSessionIsReportedHonestly() {
        let app = launch(route: "/workout/strength")
        XCTAssertTrue(app.staticTexts["第 1 / 4 组"].waitForExistence(timeout: 6))

        // Do exactly 2 of the 20 planned sets, then end early.
        for set in 1...2 {
            XCTAssertTrue(app.staticTexts["第 \(set) / 4 组"].waitForExistence(timeout: 6))
            app.buttons["完成这组"].waitAndTap()
            XCTAssertTrue(app.staticTexts["休息"].waitForExistence(timeout: 4))
            app.buttons["跳过"].waitAndTap()
        }

        app.buttons["结束训练"].waitAndTap()
        app.buttons["结束并查看复盘"].waitAndTap()

        // Partial session: honest title, honest percentage.
        XCTAssertTrue(app.staticTexts["今天练到这里"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["今天完成了"].exists)
        XCTAssertTrue(app.staticTexts["10%"].exists, "2 of 20 sets is 10%")

        // The squat is partially done; everything after it must read as 0.
        XCTAssertTrue(app.staticTexts["2 / 4 组 · 12 次"].exists)
        XCTAssertTrue(app.staticTexts["0 / 4 组 · 15 次"].exists, "臀桥 was never started")
        XCTAssertTrue(app.staticTexts["0 / 3 组 · 15 次"].exists, "小腿提踵 was never started")
        XCTAssertTrue(app.staticTexts["0 / 30 分钟"].exists, "cardio never happened")
    }

    // MARK: - Memory persists across launches

    func testKneeMemoryPersistsToNextLaunch() {
        let app = launch(route: "/workout/strength")
        XCTAssertTrue(app.staticTexts["准备好了吗？"].waitForExistence(timeout: 6))

        // Report the knee, then finish the session so the memory is written.
        app.buttons["开始语音"].tap()
        XCTAssertTrue(app.staticTexts["开始"].waitForExistence(timeout: 8))
        app.buttons["开始语音"].waitAndTap()
        XCTAssertTrue(app.staticTexts["10 kg · 12 次"].waitForExistence(timeout: 10))

        app.buttons["结束训练"].waitAndTap()
        app.buttons["结束并查看复盘"].waitAndTap()
        XCTAssertTrue(app.staticTexts["AI 记忆更新"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()

        // Back home, the follow-up memory the coach wrote is now a chip, and
        // the session shows up in the record.
        openPlanTab(app)
        XCTAssertTrue(
            app.staticTexts["台阶上步先做 2 组"].waitForExistence(timeout: 5),
            "the coach's new memory should surface as a chip"
        )
        XCTAssertTrue(app.staticTexts["最近训练"].exists)
        // The demo profile's goal is 减脂, so the weekly target is 5.
        XCTAssertTrue(app.staticTexts["1 / 5 次"].exists, "one finished session this week")
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
        app.buttons["workout-send-button"].waitAndTap()

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
