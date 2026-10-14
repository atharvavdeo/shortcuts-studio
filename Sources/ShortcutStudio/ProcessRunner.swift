import Foundation
import Darwin
import WorkflowCore

private final class ProcessSession: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    func launch(_ process: Process) throws {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { throw CancellationError() }
        self.process = process; try process.run()
    }
    func cancel() {
        lock.lock(); cancelled = true; let current = process; lock.unlock()
        if let current, current.isRunning {
            current.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if current.isRunning { kill(current.processIdentifier, SIGKILL) } }
        }
    }
}

enum ProcessRunner {
    static func run(_ executable: String, arguments: [String], timeout: Double = 120) async throws -> String {
        let session = ProcessSession()
        return try await withTaskCancellationHandler {
            let timeoutTask = Task { try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000)); session.cancel() }
            defer { timeoutTask.cancel() }
            let result = try await Task.detached(priority: .userInitiated) {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("studio-process-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: directory) }
                let out = directory.appendingPathComponent("stdout"), err = directory.appendingPathComponent("stderr")
                FileManager.default.createFile(atPath: out.path, contents: nil); FileManager.default.createFile(atPath: err.path, contents: nil)
                let stdout = try FileHandle(forWritingTo: out), stderr = try FileHandle(forWritingTo: err)
                defer { try? stdout.close(); try? stderr.close() }
                let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
                process.standardInput = FileHandle.nullDevice; process.standardOutput = stdout; process.standardError = stderr
                try session.launch(process); process.waitUntilExit()
                let outputSize = try out.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                let errorSize = try err.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard outputSize <= 10_000_000, errorSize <= 1_000_000 else { throw StudioError.message("Process output exceeded the supported limit.") }
                let output = try String(contentsOf: out, encoding: .utf8)
                if process.terminationStatus != 0 {
                    let message = (try? String(contentsOf: err, encoding: .utf8)) ?? ""
                    throw StudioError.message(message.isEmpty ? "Command ended with status \(process.terminationStatus), or exceeded its time limit." : String(message.prefix(2000)))
                }
                return output
            }.value
            try Task.checkCancellation(); return result
        } onCancel: { session.cancel() }
    }
}
