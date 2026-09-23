import XCTest

@MainActor
final class ExerciseCatalogueUITests: HiIntervalUITestCase {
    private enum CatalogueID {
        static let highKnees = "00000000-0000-0000-0000-00000000000B"
        static let reverseLunges = "00000000-0000-0000-0000-00000000000C"
        static let deadBug = "00000000-0000-0000-0000-000000000015"
        static let sidePlank = "00000000-0000-0000-0000-000000000016"
    }

    func testMigratesFixtureExercisesIntoUsableCatalogue() {
        launch()
        selectTab("settings")
        selectSegment(control: "settings.appearance", option: "Light")
        openCatalogue()

        for id in [CatalogueID.highKnees, CatalogueID.reverseLunges, CatalogueID.deadBug, CatalogueID.sidePlank] {
            waitForExistence(element("catalogue.row.\(id)"))
        }
        waitForLabel(
            "Used in Quick Start",
            on: element("catalogue.usage.\(CatalogueID.highKnees).\(FixtureID.quickStartPlan)")
        )

        capture("01-migrated-exercise-catalogue")
    }

    func testEditsExerciseMetadataPersistsAndUpdatesPlanReference() {
        launch()
        openCatalogue()

        editCatalogueExercise(
            id: CatalogueID.highKnees,
            name: "Fast High Knees",
            bodyAreas: ["legs", "cardio"],
            tags: ["achilles recovery", "warm-up"]
        )
        relaunchPreservingData()
        openCatalogue()

        tap(element("catalogue.row.\(CatalogueID.highKnees)"), scrolls: true)
        waitForExistence(element("catalogue.editor.screen"))
        waitForValue("Fast High Knees", on: element("catalogue.editor.name"))
        scrollToVisible(element("catalogue.editor.bodyAreas.pill.legs"))
        scrollToVisible(element("catalogue.editor.bodyAreas.pill.cardio"))
        scrollToVisible(element("catalogue.editor.tags.pill.achilles-recovery"))
        scrollToVisible(element("catalogue.editor.tags.pill.warm-up"))
        tapToolbarButton("catalogue.editor.save", label: "Save")

        closeCatalogue()
        selectTab("plans")
        let quickStart = element("plan.card.\(FixtureID.quickStartPlan)")
        scrollToVisible(quickStart)
        XCTAssertTrue(
            quickStart.staticTexts[planExerciseLabel("Fast High Knees")].exists,
            "A renamed catalogue exercise should update its linked plan step."
        )
        capture("02-catalogue-edit-persists-and-updates-plan")
    }

    func testMergingExercisesPreservesPlansAndHistorySnapshot() {
        launch()
        openCatalogue()

        // Merge the migrated Dead Bug entry into High Knees. The source entry is removed, while
        // every linked plan step adopts the target's canonical exercise name.
        tapToolbarButton("catalogue.select", label: "Select")
        tap(element("catalogue.select.\(CatalogueID.highKnees)"), scrolls: true)
        tap(element("catalogue.select.\(CatalogueID.deadBug)"), scrolls: true)
        tap(element("catalogue.merge"), scrolls: true)
        tapVisibleButton("Keep High Knees · Quick Start")
        waitForDisappearance(element("catalogue.row.\(CatalogueID.deadBug)"))

        closeCatalogue()

        selectTab("plans")
        let quickStart = element("plan.card.\(FixtureID.quickStartPlan)")
        let coreFocus = element("plan.card.\(FixtureID.coreFocusPlan)")
        scrollToVisible(quickStart)
        XCTAssertTrue(quickStart.staticTexts[planExerciseLabel("High Knees")].exists)
        scrollToVisible(coreFocus)
        XCTAssertTrue(coreFocus.staticTexts[planExerciseLabel("High Knees")].exists)

        // Completed workouts intentionally retain their snapshot rather than being rewritten by
        // later catalogue maintenance.
        selectTab("history")
        tap(element("history.entry.\(FixtureID.coreFocusHistory)"))
        waitForExistence(element("history.detail.screen"))
        tap(element("history.reuse"), scrolls: true)
        waitForLabel("Plan copied and selected", on: element("history.reuse.status"))
        selectTab("plans")
        scrollToVisible(app.staticTexts[planExerciseLabel("Dead Bug")])
        XCTAssertTrue(
            app.staticTexts[planExerciseLabel("Dead Bug")].exists,
            "Reusing history must keep its original snapshot."
        )
        capture("03-catalogue-merge-keeps-history")
    }

    func testGeneratorFiltersTagsAlternatesAreasAndSavesTrainablePlan() {
        launch()
        openCatalogue()

        editCatalogueExercise(
            id: CatalogueID.highKnees,
            name: "High Knees",
            bodyAreas: ["legs"],
            tags: ["achilles recovery"]
        )
        editCatalogueExercise(
            id: CatalogueID.deadBug,
            name: "Dead Bug",
            bodyAreas: ["core"],
            tags: ["achilles recovery"]
        )

        closeCatalogue()
        selectTab("plans")
        tap(element("generator.open"))
        waitForExistence(element("generator.screen"))
        setSwitch("generator.requiredTags.achilles-recovery", to: true)
        setSwitch("generator.alternate", to: true)
        // The generator starts at six exercises; make the two eligible exercises explicit.
        let decrement = app.buttons["generator.count-Decrement"]
        scrollToHittable(decrement)
        for _ in 0..<4 { decrement.tap() }
        tapToolbarButton("generator.generate", label: "Preview")

        waitForExistence(element("plan.editor.screen"), timeout: 8)
        let first = element("plan.editor.exercise.0")
        let second = element("plan.editor.exercise.1")
        scrollToVisible(first)
        let firstName = first.label
        XCTAssertTrue(firstName.contains("High Knees") || firstName.contains("Dead Bug"))
        scrollToVisible(second)
        let secondName = second.label
        XCTAssertTrue(secondName.contains("High Knees") || secondName.contains("Dead Bug"))
        XCTAssertTrue(
            (firstName.contains("High Knees") && secondName.contains("Dead Bug"))
                || (firstName.contains("Dead Bug") && secondName.contains("High Knees")),
            "Alternating distinct body areas should use both eligible exercises."
        )

        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)
        // Inspect the active session at real time: the accelerated fixture can finish before
        // a loaded simulator returns its accessibility tree. Keep the saved plan on disk.
        app.terminate()
        app = configuredApplication(resetFixture: nil)
        app.launchEnvironment["HIINTERVAL_UI_TEST_SPEED"] = "1"
        launchConfiguredApplication()
        selectTab("train")
        waitForLabel("Generated workout", on: element("train.selected-plan-name"))
        tap(element("train.start"))
        waitForExistence(element("session.screen"), timeout: 8)
        XCTAssertFalse(app.staticTexts["achilles recovery"].exists)
        capture("04-generated-plan-trains-without-planning-tags")
    }

    func testEmptyCatalogueOffersAStartingPoint() {
        launch(fixture: .empty)
        selectTab("plans")
        tap(element("catalogue.open"))
        waitForExistence(element("catalogue.screen"))
        tap(element("catalogue.add"))
        waitForExistence(element("catalogue.editor.screen"))
        let name = element("catalogue.editor.name")
        waitForExistence(name)
        waitForExistence(app.keyboards.firstMatch, timeout: 3)
        typeText("Heel Raises", intoFocusedField: name)
        XCTAssertEqual(name.value as? String, "Heel Raises")
        tapToolbarButton("catalogue.editor.save", label: "Save")
        waitForExistence(app.staticTexts["Heel Raises"])
        capture("05-empty-catalogue-creates-an-exercise")
    }

    func testPlanningLabelPillsSuggestReuseDeduplicateAndPersist() {
        launch()
        openCatalogue()

        tap(element("catalogue.row.\(CatalogueID.highKnees)"), scrolls: true)
        waitForExistence(element("catalogue.editor.screen"))

        // Body-area suggestions include a useful starting vocabulary before any labels exist.
        let legsSuggestion = element("catalogue.editor.bodyAreas.suggestion.legs")
        waitForExistence(legsSuggestion)
        revealPlanningSuggestion(legsSuggestion)
        tap(legsSuggestion)
        waitForExistence(element("catalogue.editor.bodyAreas.pill.legs"))

        addPlanningLabel("Achilles recovery", kind: "tags")
        waitForExistence(element("catalogue.editor.tags.pill.achilles-recovery"))
        // Case differences must not create two planning labels for one concept.
        addPlanningLabel("ACHILLES RECOVERY", kind: "tags")
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "catalogue.editor.tags.pill.achilles-recovery").count,
            1,
            "Planning labels should deduplicate case-insensitively."
        )
        capture("11-selected-label-pills")
        tapToolbarButton("catalogue.editor.save", label: "Save")
        waitForDisappearance(element("catalogue.editor.screen"), timeout: 8)

        tap(element("catalogue.row.\(CatalogueID.deadBug)"), scrolls: true)
        waitForExistence(element("catalogue.editor.screen"))
        let suggestion = element("catalogue.editor.tags.suggestion.achilles-recovery")
        revealPlanningSuggestion(suggestion)
        tap(suggestion)
        waitForExistence(element("catalogue.editor.tags.pill.achilles-recovery"))
        tapToolbarButton("catalogue.editor.save", label: "Save")
        waitForDisappearance(element("catalogue.editor.screen"), timeout: 8)

        relaunchPreservingData()
        openCatalogue()
        tap(element("catalogue.row.\(CatalogueID.deadBug)"), scrolls: true)
        scrollToVisible(element("catalogue.editor.tags.pill.achilles-recovery"))
        let remove = element("catalogue.editor.tags.remove.achilles-recovery")
        revealPlanningSuggestion(remove)
        tap(remove)
        waitForDisappearance(element("catalogue.editor.tags.pill.achilles-recovery"))
        tapToolbarButton("catalogue.editor.save", label: "Save")
        waitForDisappearance(element("catalogue.editor.screen"), timeout: 8)

        // Detaching a label from one exercise must retain it in the shared catalogue.
        tap(element("catalogue.row.\(CatalogueID.deadBug)"), scrolls: true)
        scrollToHittable(element("catalogue.editor.tags.suggestion.achilles-recovery"))
        capture("10-reusable-label-suggestions")
    }

    func testCancelledPlanningLabelDoesNotEnterSharedSuggestions() {
        launch()
        openCatalogue()
        tap(element("catalogue.add"))
        waitForExistence(element("catalogue.editor.screen"))
        replaceText(in: element("catalogue.editor.name"), with: "Temporary exercise")
        addPlanningLabel("Do not save", kind: "tags")
        waitForExistence(element("catalogue.editor.tags.pill.do-not-save"))
        tapToolbarButton("catalogue.editor.cancel", label: "Cancel")
        waitForDisappearance(element("catalogue.editor.screen"), timeout: 8)

        tap(element("catalogue.row.\(CatalogueID.highKnees)"), scrolls: true)
        waitForExistence(element("catalogue.editor.screen"))
        scrollToHittable(element("catalogue.editor.tags"))
        XCTAssertFalse(
            element("catalogue.editor.tags.suggestion.do-not-save").exists,
            "Cancelling an editor must not create a shared planning label."
        )
    }

    func testCancellingGeneratedPreviewDoesNotCreateAPlan() {
        launch()
        selectTab("plans")
        tap(element("generator.open"))
        waitForExistence(element("generator.screen"))
        let decrement = app.buttons["generator.count-Decrement"]
        scrollToHittable(decrement)
        for _ in 0..<2 { decrement.tap() }
        tapToolbarButton("generator.generate", label: "Preview")
        waitForExistence(element("plan.editor.screen"), timeout: 8)
        tapToolbarButton("plan.editor.cancel", label: "Cancel")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)
        tapToolbarButton("generator.cancel", label: "Cancel")
        waitForDisappearance(element("generator.screen"), timeout: 8)

        relaunchPreservingData()
        selectTab("plans")
        scrollToVisible(element("plan.card.\(FixtureID.quickStartPlan)"))
        scrollToVisible(element("plan.card.\(FixtureID.coreFocusPlan)"))
        XCTAssertFalse(app.staticTexts["Generated workout"].exists)
    }

    func testCatalogueChoiceCreatesAPlanLinkAndPlanRenameDetachesIt() {
        launch()
        selectTab("plans")
        tap(element("plans.add"))
        waitForExistence(element("plan.editor.screen"))
        replaceText(in: element("plan.editor.name"), with: "Detached catalogue plan")
        revealPlanControl(element("plan.editor.exercise.add"))
        tap(element("plan.editor.exercise.add"))
        waitForExistence(element("catalogue.screen"))
        tap(element("catalogue.row.\(CatalogueID.highKnees)"), scrolls: true)
        waitForDisappearance(element("catalogue.screen"), timeout: 8)

        let chosen = element("plan.editor.exercise.1")
        waitForLabel("Exercise 2, High Knees", on: chosen)
        revealPlanControl(chosen)
        tap(chosen)
        waitForExistence(element("exercise.editor.screen"))
        replaceText(in: element("exercise.editor.name"), with: "Plan-only High Knees")
        tapToolbarButton("exercise.editor.save", label: "Done")
        waitForLabel("Exercise 2, Plan-only High Knees", on: chosen)

        // The detached plan name must survive a full persistence cycle without changing the
        // catalogue's canonical name.
        tapToolbarButton("plan.editor.save", label: "Save")
        waitForDisappearance(element("plan.editor.screen"), timeout: 8)
        relaunchPreservingData()
        selectTab("plans")
        let detachedTitle = app.staticTexts["Detached catalogue plan"]
        scrollToVisible(detachedTitle)
        let detachedCard = planCard(containing: "Detached catalogue plan")
        tap(detachedCard.descendants(matching: .button)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.edit.'")).firstMatch, scrolls: true)
        waitForExistence(element("plan.editor.screen"))
        revealPlanControl(element("plan.editor.exercise.1"))
        waitForLabel("Exercise 2, Plan-only High Knees", on: element("plan.editor.exercise.1"))
        tapToolbarButton("plan.editor.cancel", label: "Cancel")
        openCatalogue()
        tap(element("catalogue.row.\(CatalogueID.highKnees)"), scrolls: true)
        waitForValue("High Knees", on: element("catalogue.editor.name"))
        capture("06-plan-only-name-does-not-rename-catalogue")
    }

    func testTypedNameSuggestsCatalogueAndCancellingPlanCreatesNothing() {
        launch()
        selectTab("plans")
        tap(element("plans.add"))
        revealPlanControl(element("plan.editor.exercise.add"))
        tap(element("plan.editor.exercise.add"))
        tap(element("exercise.choice.create"))
        let name = element("exercise.editor.name")
        waitForExistence(app.keyboards.firstMatch)
        typeText("high knees", intoFocusedField: name)
        tap(element("exercise.editor.suggestion.\(CatalogueID.highKnees)"), scrolls: true)
        waitForValue("High Knees", on: name)
        tapToolbarButton("exercise.editor.save", label: "Done")
        waitForLabel("Exercise 2, High Knees", on: element("plan.editor.exercise.1"))
        tapToolbarButton("plan.editor.cancel", label: "Cancel")
        relaunchPreservingData()
        openCatalogue()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'catalogue.row.'")).count, 4)
        waitForExistence(element("catalogue.row.\(CatalogueID.highKnees)"))
    }

    func testCatalogueAndGeneratorRemainUsableAtLargestTextAndIpadLandscape() {
        app = configuredApplication(resetFixture: .standard)
        app.launchEnvironment["HIINTERVAL_UI_TEST_DYNAMIC_TYPE"] = "accessibility5"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchConfiguredApplication()
        selectTab("settings")
        selectSegment(control: "settings.appearance", option: "Dark")
        selectTab("plans")
        tap(element("catalogue.open"))
        waitForExistence(element("catalogue.screen"))
        scrollToHittable(element("catalogue.row.\(CatalogueID.sidePlank)"))
        capture("07-dynamic-type-catalogue")
        tap(element("catalogue.row.\(CatalogueID.sidePlank)"))
        let longLabel = "Upper body mobility and recovery"
        addPlanningLabel(longLabel, kind: "bodyAreas")
        let pill = element("catalogue.editor.bodyAreas.pill.upper-body-mobility-and-recovery")
        let remove = element("catalogue.editor.bodyAreas.remove.upper-body-mobility-and-recovery")
        scrollToHittable(remove)
        let form = element("catalogue.editor.screen")
        XCTAssertGreaterThanOrEqual(pill.frame.minX, form.frame.minX)
        XCTAssertLessThanOrEqual(pill.frame.maxX, form.frame.maxX)
        waitForLabel("Remove \(longLabel)", on: remove)
        capture("12-dynamic-type-dark-label-pill")
        if app.frame.width > 700 {
            XCUIDevice.shared.orientation = .landscapeLeft
            defer { XCUIDevice.shared.orientation = .portrait }
            scrollToHittable(remove)
            XCTAssertGreaterThanOrEqual(pill.frame.minX, form.frame.minX)
            XCTAssertLessThanOrEqual(pill.frame.maxX, form.frame.maxX)
            capture("13-ipad-landscape-label-pill")
        }
        tap(remove)
        waitForDisappearance(pill)
        tapToolbarButton("catalogue.editor.cancel", label: "Cancel")
        waitForDisappearance(element("catalogue.editor.screen"))
        closeCatalogue()
        tap(element("generator.open"))
        waitForExistence(element("generator.screen"))
        scrollToVisible(app.staticTexts["Matching exercises"])
        capture("08-dynamic-type-generator")

        guard app.frame.width > 700 else { return }
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForExistence(element("generator.screen"), timeout: 8)
        capture("09-ipad-landscape-generator")
    }

    /// Reveal controls inside the actual sheet, excluding its floating actions and keyboard.
    /// XCTest can report a clipped control as hittable even when tapping only expands the sheet.
    private func revealPlanControl(_ target: XCUIElement) {
        // Scroll the sheet's list gutter, not a text input in the middle of a recycled row.
        // iPadOS 26 can retain a detached focus guide when a swipe starts on vertical text input.
        revealFormControl(target, identifier: "plan.editor.screen", usesLeadingGutter: true)
    }

    private func revealPlanningSuggestion(_ target: XCUIElement) {
        revealFormControl(target, identifier: "catalogue.editor.screen", usesLeadingGutter: false)
    }

    private func revealFormControl(
        _ target: XCUIElement,
        identifier: String,
        usesLeadingGutter: Bool
    ) {
        let form = app.collectionViews[identifier]
        waitForExistence(form)
        for _ in 0..<12 {
            let viewport = planningViewport(form)
            if target.exists, viewport.contains(target.frame) { return }
            let up = !target.exists || target.frame.midY > viewport.midY
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: usesLeadingGutter ? viewport.minX + 4 : viewport.midX,
                dy: viewport.minY + viewport.height * (up ? 0.8 : 0.2)
            ))
            let end = start.withOffset(CGVector(dx: 0, dy: viewport.height * (up ? -0.5 : 0.5)))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(target.exists && planningViewport(form).contains(target.frame),
                      "Planning control remains clipped: \(target)")
    }

    private func planningViewport(_ form: XCUIElement) -> CGRect {
        var viewport = form.frame.intersection(app.frame)
        for bar in app.navigationBars.allElementsBoundByIndex where bar.isHittable {
            if bar.frame.intersects(viewport), bar.frame.maxY < viewport.midY {
                let bottom = viewport.maxY
                viewport.origin.y = max(viewport.minY, bar.frame.maxY)
                viewport.size.height = bottom - viewport.minY
            }
        }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, keyboard.frame.intersects(viewport) {
            viewport.size.height = max(0, keyboard.frame.minY - viewport.minY)
        }
        let delete = app.buttons["catalogue.editor.delete"]
        if delete.exists, delete.frame.intersects(viewport), delete.frame.minY > viewport.midY {
            viewport.size.height = delete.frame.minY - viewport.minY
        }
        return viewport.insetBy(dx: 4, dy: 8)
    }

    private func openCatalogue() {
        selectTab("plans")
        tap(element("catalogue.open"))
        waitForExistence(element("catalogue.screen"))
    }

    private func closeCatalogue() {
        tapToolbarButton("catalogue.done", label: "Done")
        waitForDisappearance(element("catalogue.screen"), timeout: 8)
    }

    private func editCatalogueExercise(id: String, name: String, bodyAreas: [String], tags: [String]) {
        tap(element("catalogue.row.\(id)"), scrolls: true)
        waitForExistence(element("catalogue.editor.screen"))
        replaceText(in: element("catalogue.editor.name"), with: name)
        bodyAreas.forEach { addPlanningLabel($0, kind: "bodyAreas") }
        tags.forEach { addPlanningLabel($0, kind: "tags") }
        tapToolbarButton("catalogue.editor.save", label: "Save")
        waitForDisappearance(element("catalogue.editor.screen"), timeout: 8)
    }

    private func addPlanningLabel(_ label: String, kind: String) {
        let input = element("catalogue.editor.\(kind)")
        // Every Add clears this field. Focus once; no triple-tap selection can fall under the
        // keyboard while the Form scrolls the newly focused row into view.
        revealPlanningSuggestion(input)
        tap(input)
        waitForExistence(app.keyboards.firstMatch)
        typeText(label, intoFocusedField: input)
        tap(element("catalogue.editor.\(kind).add"), scrolls: true)
    }

    private func planCard(containing title: String) -> XCUIElement {
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.card.'"))
        for index in 0..<cards.count {
            let card = cards.element(boundBy: index)
            if card.staticTexts[title].exists { return card }
        }
        XCTFail("Could not find a plan card containing '\(title)'")
        return cards.firstMatch
    }

    private func planExerciseLabel(_ name: String) -> String {
        "Exercise: \(name)"
    }
}
