import SwiftUI
import SVNCore

@MainActor
final class OperationController: ObservableObject {
    @Published var isPresented = false
    @Published var title = ""
    @Published var lines: [String] = []
    @Published var isRunning = false

    private var task: SVNTask?

    func begin(_ title: String) {
        self.title = title
        lines = []
        isRunning = true
        isPresented = true
        task = nil
    }

    func attach(_ task: SVNTask) {
        self.task = task
    }

    func append(_ line: String) {
        lines.append(line)
    }

    func appendLines(_ text: String) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            lines.append(String(line))
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
    }

    func finish() {
        isRunning = false
        task = nil
    }

    func cancel() {
        task?.cancel()
        finish()
        lines.append("Cancelled by user.")
    }
}
