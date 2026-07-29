import Foundation
import Cgit2

/// Internal, in-process libgit2 adapter. Its lifetime is confined to one SDK
/// operation, so opaque libgit2 objects are never shared across tasks.
final class GitRepositoryHandle {
    let rootURL: URL

    private let pointer: OpaquePointer

    init(opening suppliedURL: URL) throws {
        let initializationResult = git_libgit2_init()
        guard initializationResult >= 0 else {
            throw Self.repositoryError(for: initializationResult)
        }

        guard suppliedURL.isFileURL else {
            git_libgit2_shutdown()
            throw RepositoryError.invalidDirectory
        }

        var repository: OpaquePointer?
        let result = suppliedURL.path.withCString {
            git_repository_open_ext(&repository, $0, 0, nil)
        }
        guard result == 0, let repository else {
            git_libgit2_shutdown()
            throw Self.repositoryError(for: result)
        }
        pointer = repository

        guard let workdir = git_repository_workdir(repository) else {
            git_repository_free(repository)
            git_libgit2_shutdown()
            throw RepositoryError.notGitRepository
        }
        rootURL = URL(fileURLWithPath: String(cString: workdir))
            .standardizedFileURL
    }

    deinit {
        git_repository_free(pointer)
        git_libgit2_shutdown()
    }

    func head() throws -> (branchName: String, revision: String?) {
        var reference: OpaquePointer?
        let result = git_repository_head(&reference, pointer)
        if result == GIT_EUNBORNBRANCH.rawValue
            || result == GIT_ENOTFOUND.rawValue {
            return (unbornBranchName(), nil)
        }
        try Self.check(result)
        guard let reference else {
            throw RepositoryError.invalidOutput
        }
        defer { git_reference_free(reference) }

        let branchName: String
        if git_repository_head_detached(pointer) == 1 {
            branchName = "detached"
        } else if let shorthand = git_reference_shorthand(reference) {
            branchName = String(cString: shorthand)
        } else {
            branchName = "detached"
        }

        let revision = git_reference_target(reference).map(Self.oidString)
        return (branchName, revision)
    }

    func remoteURL() -> String? {
        var remote: OpaquePointer?
        guard git_remote_lookup(&remote, pointer, "origin") == 0,
              let remote else {
            return nil
        }
        defer { git_remote_free(remote) }
        return git_remote_url(remote).map { String(cString: $0) }
    }

    func lastCommit() -> (
        summary: String?,
        author: String?,
        date: Date?
    )? {
        var object: OpaquePointer?
        guard git_revparse_single(&object, pointer, "HEAD^{commit}") == 0,
              let object else {
            return nil
        }
        defer { git_object_free(object) }

        let commit = object
        let summary = git_commit_summary(commit).map { String(cString: $0) }
        let author = git_commit_author(commit).flatMap { signature in
            signature.pointee.name.map { String(cString: $0) }
        }
        let timestamp = git_commit_time(commit)
        return (
            summary,
            author,
            Date(timeIntervalSince1970: TimeInterval(timestamp))
        )
    }

    func changes() throws -> [RepositoryChange] {
        var options = git_status_options()
        try Self.check(git_status_options_init(&options, UInt32(GIT_STATUS_OPTIONS_VERSION)))
        options.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR
        options.flags = UInt32(
            GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue
                | GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.rawValue
                | GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue
                | GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR.rawValue
        )

        var list: OpaquePointer?
        try Self.check(git_status_list_new(&list, pointer, &options))
        guard let list else {
            throw RepositoryError.invalidOutput
        }
        defer { git_status_list_free(list) }

        var result: [RepositoryChange] = []
        for index in 0..<git_status_list_entrycount(list) {
            guard let entry = git_status_byindex(list, index) else { continue }
            let status = entry.pointee.status
            let headToIndex = entry.pointee.head_to_index
            let indexToWorkdir = entry.pointee.index_to_workdir

            if status.contains(GIT_STATUS_CONFLICTED) {
                if let path = Self.path(from: indexToWorkdir ?? headToIndex) {
                    result.append(.init(
                        path: path,
                        status: .conflicted,
                        area: .conflicted
                    ))
                }
                continue
            }

            if status.contains(GIT_STATUS_WT_NEW) {
                if let path = Self.path(from: indexToWorkdir) {
                    result.append(.init(
                        path: path,
                        status: .untracked,
                        area: .untracked
                    ))
                }
                continue
            }

            if status.intersection(Self.indexStatusMask) != 0,
               let delta = headToIndex,
               let change = Self.change(from: delta, area: .staged) {
                result.append(change)
            }
            if status.intersection(Self.worktreeStatusMask) != 0,
               let delta = indexToWorkdir,
               let change = Self.change(from: delta, area: .unstaged) {
                result.append(change)
            }
        }

        return result.sorted {
            if $0.path == $1.path { return $0.area.rawValue < $1.area.rawValue }
            return $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    func diff(for change: RepositoryChange) throws -> String {
        if change.area == .untracked {
            return try untrackedDiff(path: change.path)
        }

        guard let cPath = strdup(change.path) else {
            throw RepositoryError.invalidOutput
        }
        defer { free(cPath) }
        let pathPointers = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
            .allocate(capacity: 1)
        pathPointers.initialize(to: cPath)
        defer {
            pathPointers.deinitialize(count: 1)
            pathPointers.deallocate()
        }

        var options = git_diff_options()
        try Self.check(git_diff_options_init(&options, UInt32(GIT_DIFF_OPTIONS_VERSION)))
        options.flags = UInt32(GIT_DIFF_DISABLE_PATHSPEC_MATCH.rawValue)
        options.pathspec = git_strarray(strings: pathPointers, count: 1)

        var diff: OpaquePointer?
        switch change.area {
        case .staged:
            var headTree: OpaquePointer?
            let treeResult = git_revparse_single(&headTree, pointer, "HEAD^{tree}")
            if treeResult == GIT_ENOTFOUND.rawValue
                || treeResult == GIT_EUNBORNBRANCH.rawValue {
                try Self.check(git_diff_tree_to_index(
                    &diff, pointer, nil, nil, &options
                ))
            } else {
                try Self.check(treeResult)
                defer { git_object_free(headTree) }
                try Self.check(git_diff_tree_to_index(
                    &diff, pointer, headTree, nil, &options
                ))
            }
        case .unstaged, .conflicted:
            try Self.check(git_diff_index_to_workdir(
                &diff, pointer, nil, &options
            ))
        case .untracked:
            break
        }

        guard let diff else {
            throw RepositoryError.invalidOutput
        }
        defer { git_diff_free(diff) }

        var buffer = git_buf()
        try Self.check(git_diff_to_buf(&buffer, diff, GIT_DIFF_FORMAT_PATCH))
        defer { git_buf_dispose(&buffer) }
        guard let content = buffer.ptr else { return "" }
        return String(decoding: UnsafeBufferPointer(
            start: UnsafeRawPointer(content).assumingMemoryBound(to: UInt8.self),
            count: buffer.size
        ), as: UTF8.self)
    }

    func files() throws -> [String] {
        var paths = Set<String>()
        var index: OpaquePointer?
        try Self.check(git_repository_index(&index, pointer))
        guard let index else {
            throw RepositoryError.invalidOutput
        }
        defer { git_index_free(index) }

        for position in 0..<git_index_entrycount(index) {
            guard let entry = git_index_get_byindex(index, position),
                  let path = entry.pointee.path else { continue }
            paths.insert(String(cString: path))
        }

        for change in try changes() where change.area == .untracked {
            paths.insert(change.path)
        }
        return Array(paths)
    }

    private func unbornBranchName() -> String {
        var headReference: OpaquePointer?
        guard git_reference_lookup(
            &headReference,
            pointer,
            "HEAD"
        ) == 0, let headReference else {
            return "detached"
        }
        defer { git_reference_free(headReference) }
        guard let target = git_reference_symbolic_target(headReference) else {
            return "detached"
        }
        let name = String(cString: target)
        let branchPrefix = "refs/heads/"
        if name.hasPrefix(branchPrefix) {
            return String(name.dropFirst(branchPrefix.count))
        }
        return name.isEmpty ? "detached" : name
    }

    private func untrackedDiff(path: String) throws -> String {
        let url = rootURL.appendingPathComponent(path)
        let data = try Data(contentsOf: url)
        guard !data.contains(0), let content = String(data: data, encoding: .utf8) else {
            throw RepositoryError.binaryFileUnsupported
        }
        let lines = content.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let body = lines.map { "+\($0)" }.joined(separator: "\n")
        return """
        diff --git a/\(path) b/\(path)
        new file mode 100644
        --- /dev/null
        +++ b/\(path)
        @@ -0,0 +1,\(lines.count) @@
        \(body)
        """
    }

    private static func path(
        from delta: UnsafePointer<git_diff_delta>?
    ) -> String? {
        guard let delta else { return nil }
        return (delta.pointee.new_file.path ?? delta.pointee.old_file.path)
            .map { String(cString: $0) }
    }

    private static func change(
        from delta: UnsafePointer<git_diff_delta>,
        area: RepositoryChangeArea
    ) -> RepositoryChange? {
        guard let path = path(from: delta) else { return nil }
        let originalPath = delta.pointee.old_file.path.map(String.init(cString:))
        let status: RepositoryChangeStatus
        switch delta.pointee.status {
        case GIT_DELTA_ADDED: status = .added
        case GIT_DELTA_DELETED: status = .deleted
        case GIT_DELTA_RENAMED: status = .renamed
        case GIT_DELTA_COPIED: status = .copied
        case GIT_DELTA_CONFLICTED: status = .conflicted
        default: status = .modified
        }
        return RepositoryChange(
            path: path,
            originalPath: originalPath == path ? nil : originalPath,
            status: status,
            area: area
        )
    }

    private static func oidString(_ oid: UnsafePointer<git_oid>) -> String {
        var buffer = [CChar](repeating: 0, count: 41)
        git_oid_tostr(&buffer, buffer.count, oid)
        let bytes = buffer
            .prefix { $0 != 0 }
            .map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func check(_ result: Int32) throws {
        guard result >= 0 else {
            throw repositoryError(for: result)
        }
    }

    private static func repositoryError(for result: Int32) -> RepositoryError {
        if result == GIT_ENOTFOUND.rawValue {
            return .notGitRepository
        }
        let message: String
        if let error = git_error_last(), let detail = error.pointee.message {
            message = String(cString: detail)
        } else {
            message = "libgit2 error \(result)"
        }
        if message.lowercased().contains("not a git repository") {
            return .notGitRepository
        }
        return .commandFailed(exitCode: result, message: message)
    }

    private static let indexStatusMask =
        GIT_STATUS_INDEX_NEW.rawValue
        | GIT_STATUS_INDEX_MODIFIED.rawValue
        | GIT_STATUS_INDEX_DELETED.rawValue
        | GIT_STATUS_INDEX_RENAMED.rawValue
        | GIT_STATUS_INDEX_TYPECHANGE.rawValue

    private static let worktreeStatusMask =
        GIT_STATUS_WT_MODIFIED.rawValue
        | GIT_STATUS_WT_DELETED.rawValue
        | GIT_STATUS_WT_RENAMED.rawValue
        | GIT_STATUS_WT_TYPECHANGE.rawValue
}

private extension git_status_t {
    func contains(_ flag: git_status_t) -> Bool {
        rawValue & flag.rawValue != 0
    }

    func intersection(_ mask: UInt32) -> UInt32 {
        rawValue & mask
    }
}
