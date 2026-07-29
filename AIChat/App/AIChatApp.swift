//
//  AIChatApp.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import SwiftUI
import AIChatSDK

@main
struct AIChatApp: App {

    /// Built once for the app's lifetime. The composition root.
    @State private var dependencies: AppDependencies

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") {
            let mode: AIChatMode = arguments.contains("--ui-testing-code-mode")
                ? .code
                : .standard
            let repositoryURL: URL?
            if arguments.contains(
                "--ui-testing-create-repository-fixture"
            ) {
                repositoryURL = Self.makeUITestRepositoryFixture()
            } else if let pathIndex = arguments.firstIndex(
                of: "--ui-testing-repository-path"
            ), arguments.indices.contains(pathIndex + 1) {
                repositoryURL = URL(
                    fileURLWithPath: arguments[pathIndex + 1],
                    isDirectory: true
                )
            } else {
                repositoryURL = nil
            }
            let repositoryError: RepositoryError?
            if let errorIndex = arguments.firstIndex(
                of: "--ui-testing-repository-error"
            ), arguments.indices.contains(errorIndex + 1) {
                repositoryError = Self.repositoryError(
                    named: arguments[errorIndex + 1]
                )
            } else {
                repositoryError = nil
            }
            _dependencies = State(
                initialValue: AppDependencies.makeForUITesting(
                    mode: mode,
                    repositoryURL: repositoryURL,
                    repositoryError: repositoryError
                )
            )
        } else {
            _dependencies = State(
                initialValue: AppDependencies.makeDefault()
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                // Minimum size guard: sidebar + chat stays usable.
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
    }

    private static func makeUITestRepositoryFixture() -> URL? {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        removeStaleUITestRepositoryFixtures(
            in: temporaryDirectory,
            fileManager: fileManager
        )
        let root = temporaryDirectory.appendingPathComponent(
            "AIChatUITestRepository-\(UUID().uuidString)",
            isDirectory: true
        )
        let gitDirectory = root.appendingPathComponent(
            ".git",
            isDirectory: true
        )

        do {
            for path in ["objects", "refs/heads", "refs/tags"] {
                try fileManager.createDirectory(
                    at: gitDirectory.appendingPathComponent(
                        path,
                        isDirectory: true
                    ),
                    withIntermediateDirectories: true
                )
            }
            try Data("ref: refs/heads/main\n".utf8).write(
                to: gitDirectory.appendingPathComponent("HEAD")
            )
            try Data(
                """
                [core]
                    repositoryformatversion = 0
                    filemode = true
                    bare = false
                """.utf8
            ).write(to: gitDirectory.appendingPathComponent("config"))
            try Data("# UI Test Repository\n".utf8).write(
                to: root.appendingPathComponent("README.md")
            )
            try Data("// UI test change\n".utf8).write(
                to: root.appendingPathComponent("Changes.swift")
            )
            _ = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { _ in
                try? FileManager.default.removeItem(at: root)
            }
            return root
        } catch {
            try? fileManager.removeItem(at: root)
            return nil
        }
    }

    private static func removeStaleUITestRepositoryFixtures(
        in directory: URL,
        fileManager: FileManager
    ) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix(
            "AIChatUITestRepository-"
        ) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func repositoryError(
        named name: String
    ) -> RepositoryError? {
        switch name {
        case "staleBookmark":
            .staleBookmark
        case "securityScopedAccessDenied":
            .securityScopedAccessDenied
        case "notGitRepository":
            .notGitRepository
        case "invalidBookmark":
            .invalidBookmark
        default:
            nil
        }
    }
}
