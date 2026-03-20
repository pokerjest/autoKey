import AppKit
import Foundation
import SwiftUI

@MainActor
final class TypingViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var startDelay: String = "3"
    @Published var minInterval: String = "0.08"
    @Published var maxInterval: String = "0.20"
    @Published var lineBreakDelay: String = "0.35"
    @Published var status: String = "等待开始"
    @Published var isTyping = false

    private var typingTask: Task<Void, Never>?

    func clearText() {
        content = ""
        status = "内容已清空"
    }

    func stopTyping() {
        typingTask?.cancel()
        typingTask = nil
        isTyping = false
        status = "已停止"
    }

    func startTyping() {
        guard !isTyping else {
            status = "当前已经在输入中"
            return
        }

        let trimmed = content.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            status = "请先输入要发送的内容"
            return
        }

        guard
            let startDelayValue = Double(startDelay),
            let minIntervalValue = Double(minInterval),
            let maxIntervalValue = Double(maxInterval),
            let lineBreakDelayValue = Double(lineBreakDelay),
            startDelayValue >= 0,
            minIntervalValue >= 0,
            maxIntervalValue >= 0,
            lineBreakDelayValue >= 0,
            minIntervalValue <= maxIntervalValue
        else {
            status = "参数无效，请检查数字范围"
            return
        }

        isTyping = true
        status = String(format: "%.1f 秒后开始，请切到目标输入框", startDelayValue)

        typingTask = Task { [weak self] in
            guard let self else { return }
            await self.runTyping(
                text: trimmed,
                startDelay: startDelayValue,
                minInterval: minIntervalValue,
                maxInterval: maxIntervalValue,
                lineBreakDelay: lineBreakDelayValue
            )
        }
    }

    private func runTyping(
        text: String,
        startDelay: Double,
        minInterval: Double,
        maxInterval: Double,
        lineBreakDelay: Double
    ) async {
        do {
            try await sleep(seconds: startDelay)

            let characters = Array(text)
            for (index, char) in characters.enumerated() {
                try Task.checkCancellation()
                try sendCharacter(char)
                status = "输入中 \(index + 1)/\(characters.count)"

                var delay = Double.random(in: minInterval...maxInterval)
                if char == "\n" {
                    delay += lineBreakDelay
                }
                try await sleep(seconds: delay)
            }

            status = "输入完成"
            isTyping = false
            typingTask = nil
        } catch is CancellationError {
            status = "已停止"
            isTyping = false
            typingTask = nil
        } catch {
            status = "发送失败，请检查辅助功能权限"
            isTyping = false
            typingTask = nil
            showError(message: error.localizedDescription)
        }
    }

    private func sleep(seconds: Double) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func sendCharacter(_ char: Character) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript(for: char)]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw NSError(
                domain: "AutoKeyWriter",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorText]
            )
        }
    }

    private func appleScript(for char: Character) -> String {
        switch char {
        case "\n":
            return #"tell application "System Events" to key code 36"#
        case "\t":
            return #"tell application "System Events" to key code 48"#
        default:
            let escaped = String(char)
                .replacingOccurrences(of: #"\"#, with: #"\\\"#)
                .replacingOccurrences(of: #"""#, with: #"\""#)
            return #"tell application "System Events" to keystroke "\#(escaped)""#
        }
    }

    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "发送失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

struct ContentView: View {
    @StateObject private var model = TypingViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("模拟手动输入到当前激活窗口")
                    .font(.system(size: 24, weight: .bold))
                Text("把焦点切到起点作家助手的输入框后，本工具会逐字输入。")
                    .foregroundStyle(.secondary)
            }

            GroupBox("输入参数") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("开始前倒计时(秒)")
                        TextField("", text: $model.startDelay)
                            .textFieldStyle(.roundedBorder)
                        Text("字符最小间隔(秒)")
                        TextField("", text: $model.minInterval)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("字符最大间隔(秒)")
                        TextField("", text: $model.maxInterval)
                            .textFieldStyle(.roundedBorder)
                        Text("换行附加停顿(秒)")
                        TextField("", text: $model.lineBreakDelay)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("待输入内容") {
                TextEditor(text: $model.content)
                    .font(.system(size: 15))
                    .frame(minHeight: 260)
            }

            HStack(spacing: 10) {
                Button("开始输入") {
                    model.startTyping()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isTyping)

                Button("停止") {
                    model.stopTyping()
                }
                .disabled(!model.isTyping)

                Button("清空") {
                    model.clearText()
                }

                Spacer()

                Text(model.status)
                    .foregroundStyle(.teal)
            }

            Text("首次使用需要在系统设置的“隐私与安全性 -> 辅助功能”里允许本应用控制电脑。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 620)
    }
}

@main
struct AutoKeyWriterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
