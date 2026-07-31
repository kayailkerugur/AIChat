//
//  AIChatUITests.swift
//  AIChatUITests
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import XCTest

final class AIChatUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStandardModeDoesNotExposeRepositoryControls() {
        let app = makeApplication()
        app.launch()
        ensureWindowIsOpen(in: app)

        XCTAssertTrue(element("new-conversation", in: app).waitForExistence(
            timeout: 5
        ))
        XCTAssertFalse(element("new-project", in: app).exists)
        XCTAssertFalse(
            element("project-select-repository", in: app).exists
        )
    }

    @MainActor
    func testCodeModeProjectOwnsRepositoryAndConversation() {
        let app = makeApplication(codeMode: true)
        app.launch()
        ensureWindowIsOpen(in: app)

        XCTAssertTrue(
            element("new-project", in: app).waitForExistence(timeout: 5)
        )

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()

        XCTAssertTrue(
            element("project-select-repository", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            element("code-mode-select-repository", in: app).exists
        )

        let newConversationButton = element(
            "sidebar-new-conversation",
            in: app
        )
        XCTAssertTrue(newConversationButton.waitForExistence(timeout: 5))
        newConversationButton.click()

        XCTAssertTrue(
            app.staticTexts["Yeni Sohbet"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            element("project-select-repository", in: app).exists
        )
    }

    @MainActor
    func testCodeModeProjectCanBeRenamed() {
        let app = makeApplication(codeMode: true)
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.rightClick()
        app.menuItems["Yeniden Adlandır"].click()

        let field = app.textFields["Proje adı"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Renamed Project")
        app.sheets.buttons["Kaydet"].click()

        XCTAssertTrue(
            app.buttons["Renamed Project"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testCodeModeConversationCanMoveBetweenProjects() {
        let app = makeApplication(codeMode: true)
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()

        let conversation = element(
            Self.conversationIdentifier,
            in: app
        ).firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 5))
        conversation.rightClick()

        let moveMenu = app.menuItems["Projeye Taşı"]
        XCTAssertTrue(moveMenu.waitForExistence(timeout: 5))
        moveMenu.hover()

        let destination = app.menuItems["UI Test Project 2"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.click()

        XCTAssertTrue(waitForDisappearance(of: conversation))

        let secondProject = element(Self.secondProjectIdentifier, in: app)
        secondProject.click()
        XCTAssertTrue(
            element(Self.conversationIdentifier, in: app).firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testDeletingProjectPreservesItsConversation() {
        let app = makeApplication(codeMode: true)
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.rightClick()
        app.menuItems["Projeyi Sil"].click()

        let deleteButton = app.sheets.buttons["Projeyi Sil"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.click()

        XCTAssertTrue(waitForDisappearance(of: project))
        XCTAssertTrue(
            element(Self.conversationIdentifier, in: app).firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testRepositorySelectionCanBeRequestedAgain() {
        let app = makeApplication(codeMode: true)
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()

        let repositoryButton = element(
            "project-select-repository",
            in: app
        )
        XCTAssertTrue(repositoryButton.waitForExistence(timeout: 5))
        repositoryButton.click()

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            repositoryButton.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testSelectedGitRepositoryShowsBranchChangesAndFiles() {
        let app = makeApplication(
            codeMode: true,
            createsRepositoryFixture: true
        )
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()

        let branch = element("project-repository-branch", in: app)
        XCTAssertTrue(branch.waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Branch: main"].waitForExistence(timeout: 5)
        )

        let change = element(
            "repository-change-Changes.swift",
            in: app
        )
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        XCTAssertTrue(
            element("repository-file-README.md", in: app)
                .waitForExistence(timeout: 5)
        )

        let refreshButton = element(
            "project-refresh-repository",
            in: app
        )
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        refreshButton.click()
        XCTAssertTrue(
            element("repository-change-Changes.swift", in: app)
                .waitForExistence(timeout: 5)
        )

        change.click()
        let preview = element("repository-preview-content", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(
            (preview.value as? String)?.contains("UI test change")
                == true
        )
    }

    @MainActor
    func testContextFileCanBeOpenedAndSavedFromProjectDetail() {
        let app = makeApplication(
            codeMode: true,
            createsRepositoryFixture: true
        )
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()
        XCTAssertTrue(
            element("project-repository-branch", in: app)
                .waitForExistence(timeout: 10)
        )

        let editor = element("context-file-editor", in: app)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.click()
        editor.typeKey(.end, modifierFlags: .command)
        editor.typeText("\nEdited from project detail")

        let saveButton = element("save-context-file", in: app)
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.click()
        XCTAssertTrue(
            app.staticTexts["README.md kaydedildi."]
                .waitForExistence(timeout: 5)
        )

        let conversation = element(
            Self.conversationIdentifier,
            in: app
        ).firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 5))
        conversation.click()
        XCTAssertTrue(
            element("chat-repository-context", in: app)
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            element("chat-repository-branch", in: app).exists
        )

        let messageField = app.textViews["Mesaj alanı"]
        XCTAssertTrue(messageField.waitForExistence(timeout: 5))
        messageField.click()
        messageField.typeText("@")
        XCTAssertTrue(
            element("repository-file-picker", in: app)
                .waitForExistence(timeout: 5)
        )
        let readmeMention = element(
            "repository-mention-README.md",
            in: app
        )
        XCTAssertTrue(readmeMention.waitForExistence(timeout: 5))
        readmeMention.click()
        XCTAssertTrue(
            element("selected-repository-file", in: app)
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testStaleBookmarkRequestsRepositoryPermissionRenewal() {
        assertRepositoryError(
            named: "staleBookmark",
            message: "Repository erişim izni yenilenmeli."
        )
    }

    @MainActor
    func testRepositoryAccessDenialIsExplained() {
        assertRepositoryError(
            named: "securityScopedAccessDenied",
            message: "macOS repository klasörüne erişim izni vermedi."
        )
    }

    @MainActor
    func testNonGitFolderIsExplained() {
        assertRepositoryError(
            named: "notGitRepository",
            message: "Seçilen klasör bir Git repository değil."
        )
    }

    private static let projectIdentifier =
        "project-00000000-0000-0000-0000-000000000042"
    private static let secondProjectIdentifier =
        "project-00000000-0000-0000-0000-000000000043"
    private static let conversationIdentifier =
        "conversation-00000000-0000-0000-0000-000000000044"

    private func makeApplication(
        codeMode: Bool = false,
        repositoryURL: URL? = nil,
        createsRepositoryFixture: Bool = false,
        repositoryError: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-ApplePersistenceIgnoreState",
            "YES"
        ]
        if codeMode {
            app.launchArguments.append("--ui-testing-code-mode")
        }
        if let repositoryURL {
            app.launchArguments.append("--ui-testing-repository-path")
            app.launchArguments.append(repositoryURL.path)
        }
        if createsRepositoryFixture {
            app.launchArguments.append(
                "--ui-testing-create-repository-fixture"
            )
        }
        if let repositoryError {
            app.launchArguments.append("--ui-testing-repository-error")
            app.launchArguments.append(repositoryError)
        }
        return app
    }

    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func ensureWindowIsOpen(in app: XCUIApplication) {
        guard app.windows.count == 0 else { return }
        app.menuBars.menuBarItems["File"].click()
        app.menuItems["New Window"].click()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }

    private func assertRepositoryError(
        named errorName: String,
        message: String
    ) {
        let app = makeApplication(
            codeMode: true,
            repositoryError: errorName
        )
        app.launch()
        ensureWindowIsOpen(in: app)

        let project = element(Self.projectIdentifier, in: app)
        XCTAssertTrue(project.waitForExistence(timeout: 5))
        project.click()

        XCTAssertTrue(
            element("project-repository-error", in: app)
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts[message].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            element("project-select-repository", in: app).exists
        )
    }

    private func waitForDisappearance(
        of element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        return XCTWaiter.wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: predicate,
                    object: element
                )
            ],
            timeout: timeout
        ) == .completed
    }

}
