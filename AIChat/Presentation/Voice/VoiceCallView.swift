//
//  VoiceCallView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import AppKit
import SwiftUI

struct VoiceCallView: View {

    @State private var viewModel: VoiceCallViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: VoiceCallViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 22) {
            header
            callIndicator
            transcriptPanel
            controls
        }
        .padding(24)
        .frame(
            minWidth: 420, idealWidth: 560, maxWidth: 900,
            minHeight: 480, idealHeight: 620, maxHeight: 1000
        )
        .background(WindowResizeEnabler())
        .onDisappear {
            viewModel.stopSpeakingAndReset()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sesli Görüşme")
                    .font(.title2.bold())
                Text(viewModel.status.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let activeModelName = viewModel.activeModelName {
                    Text(activeModelName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Görüşmeyi kapat")
        }
    }

    private var callIndicator: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.18))
                .frame(width: 132, height: 132)
            Circle()
                .stroke(indicatorColor.opacity(0.5), lineWidth: 2)
                .frame(width: 132, height: 132)
            Image(systemName: indicatorIcon)
                .font(.system(size: 48))
                .foregroundStyle(indicatorColor)
        }
        .padding(.top, 4)
    }

    private var transcriptPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            transcriptSection(
                title: "Siz",
                text: viewModel.lastUserTranscript
            )
            Divider()
            transcriptSection(
                title: "Asistan",
                text: viewModel.lastAssistantReply
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func transcriptSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? "..." : text)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if viewModel.status == .speaking {
                pauseResumeButton
            }
            pushToTalkButton
            if case .failed(let message) = viewModel.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }

    private var pauseResumeButton: some View {
        Button {
            viewModel.togglePauseResume()
        } label: {
            Label(
                viewModel.isSpeechPaused ? "Devam Et" : "Duraklat",
                systemImage: viewModel.isSpeechPaused ? "play.fill" : "pause.fill"
            )
        }
        .buttonStyle(.bordered)
    }

    private var pushToTalkButton: some View {
        Circle()
            .fill(viewModel.isRecording ? Color.red : Color.accentColor)
            .frame(width: 72, height: 72)
            .overlay {
                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }
            .opacity(viewModel.canStartRecording ? 1 : 0.4)
            .scaleEffect(viewModel.isRecording ? 1.08 : 1)
            .animation(.spring(response: 0.2), value: viewModel.isRecording)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        viewModel.startRecording()
                    }
                    .onEnded { _ in
                        viewModel.stopRecordingAndSend()
                    }
            )
            .allowsHitTesting(viewModel.canStartRecording)
            .accessibilityLabel("Basılı tutup konuşun — yanıt okunurken de basarak sözünü kesebilirsiniz")
    }

    private var indicatorColor: Color {
        switch viewModel.status {
        case .recording:
            return .red
        case .transcribing, .waitingForReply:
            return .orange
        case .speaking:
            return .green
        case .failed:
            return .red
        case .idle:
            return .secondary
        }
    }

    private var indicatorIcon: String {
        switch viewModel.status {
        case .failed:
            return "exclamationmark.triangle"
        case .speaking:
            return "waveform"
        case .recording:
            return "mic.fill"
        default:
            return "mic"
        }
    }
}

/// A `.sheet`'s NSWindow doesn't pick up `.resizable` just because its
/// SwiftUI content has a flexible frame range — AppKit still needs the
/// style mask set explicitly, so this reaches into the window once it's
/// available and adds it.
private struct WindowResizeEnabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.styleMask.insert(.resizable)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
