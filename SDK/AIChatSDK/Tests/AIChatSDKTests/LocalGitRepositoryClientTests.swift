import Foundation
import XCTest
@testable import AIChatSDK

final class LocalGitRepositoryClientTests: XCTestCase {
    func test_fixedProviderReturnsDeveloperConfiguredRepository() async throws {
        let url = URL(fileURLWithPath: "/tmp/example-repository")
        let provider = FixedRepositoryProvider(
            rootURL: url,
            displayName: "Example"
        )

        let client = try await provider.activeRepositoryClient()
        let repository = client.repository

        XCTAssertEqual(repository.displayName, "Example")
        XCTAssertEqual(repository.rootURL, url)
    }

    func test_statusReportsBranchAndReadOnlyChangeAreas() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }

        try fixture.write("initial\n", to: "tracked.txt")
        try fixture.git(["add", "tracked.txt"])
        try fixture.git(["commit", "-m", "Initial"])
        try fixture.git([
            "remote", "add", "origin",
            "https://example.com/acme/project.git"
        ])

        try fixture.write("initial\nunstaged\n", to: "tracked.txt")
        try fixture.write("staged\n", to: "staged.txt")
        try fixture.git(["add", "staged.txt"])
        try fixture.write("untracked\n", to: "untracked.txt")

        let client = LocalGitRepositoryClient(rootURL: fixture.url)
        let status = try await client.status()

        XCTAssertEqual(status.branchName, "main")
        XCTAssertNotNil(status.headRevision)
        XCTAssertEqual(
            status.remoteURL,
            "https://example.com/acme/project.git"
        )
        XCTAssertEqual(status.lastCommitSummary, "Initial")
        XCTAssertEqual(status.lastCommitAuthor, "AIChatSDK Tests")
        XCTAssertNotNil(status.lastCommitDate)
        XCTAssertTrue(status.changes.contains {
            $0.path == "tracked.txt" && $0.area == .unstaged && $0.status == .modified
        })
        XCTAssertTrue(status.changes.contains {
            $0.path == "staged.txt" && $0.area == .staged && $0.status == .added
        })
        XCTAssertTrue(status.changes.contains {
            $0.path == "untracked.txt" && $0.area == .untracked && $0.status == .untracked
        })
    }

    func test_statusReportsUnbornBranchBeforeFirstCommit() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }
        try fixture.write("untracked\n", to: "untracked.txt")

        let status = try await LocalGitRepositoryClient(
            rootURL: fixture.url
        ).status()

        XCTAssertEqual(status.branchName, "main")
        XCTAssertNil(status.headRevision)
        XCTAssertTrue(status.changes.contains {
            $0.path == "untracked.txt" && $0.area == .untracked
        })
    }

    func test_diffReturnsStagedUnstagedAndUntrackedContent() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }

        try fixture.write("initial\n", to: "tracked.txt")
        try fixture.git(["add", "tracked.txt"])
        try fixture.git(["commit", "-m", "Initial"])
        try fixture.write("initial\nchanged\n", to: "tracked.txt")
        try fixture.write("staged content\n", to: "staged.txt")
        try fixture.git(["add", "staged.txt"])
        try fixture.write("untracked content\n", to: "untracked.txt")

        let client = LocalGitRepositoryClient(rootURL: fixture.url)
        let status = try await client.status()

        let unstaged = try XCTUnwrap(status.changes.first {
            $0.path == "tracked.txt" && $0.area == .unstaged
        })
        let staged = try XCTUnwrap(status.changes.first {
            $0.path == "staged.txt" && $0.area == .staged
        })
        let untracked = try XCTUnwrap(status.changes.first {
            $0.path == "untracked.txt" && $0.area == .untracked
        })

        let unstagedDiff = try await client.diff(for: unstaged)
        let stagedDiff = try await client.diff(for: staged)
        let untrackedDiff = try await client.diff(for: untracked)

        XCTAssertTrue(unstagedDiff.contains("+changed"))
        XCTAssertTrue(stagedDiff.contains("+staged content"))
        XCTAssertTrue(untrackedDiff.contains("+untracked content"))
    }

    func test_nonGitDirectoryIsRejected() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }

        let client = LocalGitRepositoryClient(rootURL: url)

        do {
            _ = try await client.status()
            XCTFail("Expected notGitRepository")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .notGitRepository)
        }
    }

    func test_diffRejectsPathOutsideRepository() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }
        let client = LocalGitRepositoryClient(rootURL: fixture.url)
        let change = RepositoryChange(
            path: "../outside.txt",
            status: .untracked,
            area: .untracked
        )

        do {
            _ = try await client.diff(for: change)
            XCTFail("Expected invalidPath")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .invalidPath)
        }
    }

    func test_filesIncludesTrackedAndUntrackedButHonorsGitIgnore() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }

        try fixture.write("tracked\n", to: "tracked.swift")
        try fixture.git(["add", "tracked.swift"])
        try fixture.write("untracked\n", to: "notes.txt")
        try fixture.write("ignored.txt\n", to: ".gitignore")
        try fixture.write("ignored\n", to: "ignored.txt")

        let files = try await LocalGitRepositoryClient(
            rootURL: fixture.url
        ).files()
        let paths = Set(files.map(\.path))

        XCTAssertTrue(paths.contains("tracked.swift"))
        XCTAssertTrue(paths.contains("notes.txt"))
        XCTAssertTrue(paths.contains(".gitignore"))
        XCTAssertFalse(paths.contains("ignored.txt"))
    }

    func test_readFileRedactsSecretsWithoutChangingSource() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }
        let source = """
        api_key = "super-secret-value"
        token = ghp_abcdefghijklmnopqrstuvwxyz
        safe = "visible"
        """
        try fixture.write(source, to: "Config.txt")

        let content = try await LocalGitRepositoryClient(
            rootURL: fixture.url
        ).readFile(at: "Config.txt", maximumByteCount: 10_000)

        XCTAssertTrue(content.containsRedactions)
        XCTAssertTrue(content.content.contains("api_key = [REDACTED]"))
        XCTAssertTrue(content.content.contains("token = [REDACTED]"))
        XCTAssertTrue(content.content.contains("safe = \"visible\""))
        XCTAssertEqual(
            try String(
                contentsOf: fixture.url.appendingPathComponent("Config.txt"),
                encoding: .utf8
            ),
            source
        )
    }

    func test_readFileReportsTruncationAtConfiguredLimit() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }
        try fixture.write("123456789", to: "large.txt")

        let content = try await LocalGitRepositoryClient(
            rootURL: fixture.url
        ).readFile(at: "large.txt", maximumByteCount: 5)

        XCTAssertEqual(content.content, "12345")
        XCTAssertTrue(content.wasTruncated)
    }

    func test_readFileRejectsBinaryContent() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }
        try fixture.write(Data([0x41, 0x00, 0x42]), to: "binary.dat")

        do {
            _ = try await LocalGitRepositoryClient(
                rootURL: fixture.url
            ).readFile(at: "binary.dat", maximumByteCount: 100)
            XCTFail("Expected binaryFileUnsupported")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .binaryFileUnsupported)
        }
    }

    func test_readFileRejectsSymlinkEvenWhenTargetIsInsideRepository() async throws {
        let fixture = try GitRepositoryFixture()
        defer { fixture.remove() }
        try fixture.write("target\n", to: "target.txt")
        try FileManager.default.createSymbolicLink(
            at: fixture.url.appendingPathComponent("link.txt"),
            withDestinationURL: fixture.url.appendingPathComponent("target.txt")
        )

        do {
            _ = try await LocalGitRepositoryClient(
                rootURL: fixture.url
            ).readFile(at: "link.txt", maximumByteCount: 100)
            XCTFail("Expected symbolicLinkUnsupported")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .symbolicLinkUnsupported)
        }
    }
}

private final class GitRepositoryFixture {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try git(["init", "-b", "main"])
        try git(["config", "user.name", "AIChatSDK Tests"])
        try git(["config", "user.email", "tests@aichat.invalid"])
    }

    func write(_ content: String, to path: String) throws {
        let fileURL = url.appendingPathComponent(path)
        try Data(content.utf8).write(to: fileURL, options: .atomic)
    }

    func write(_ data: Data, to path: String) throws {
        try data.write(
            to: url.appendingPathComponent(path),
            options: .atomic
        )
    }

    func git(_ arguments: [String]) throws {
        let process = Process()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", url.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = standardError
        try process.run()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RepositoryError.commandFailed(
                exitCode: process.terminationStatus,
                message: String(decoding: errorData, as: UTF8.self)
            )
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
