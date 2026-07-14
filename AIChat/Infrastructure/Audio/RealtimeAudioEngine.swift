//
//  RealtimeAudioEngine.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import AVFoundation
import Foundation

final class RealtimeAudioEngine {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var inputConverter: AVAudioConverter?
    private var inputPCMFormat: AVAudioFormat?
    private var outputPCMFormat: AVAudioFormat?

    private func pcm16Format(sampleRate: Double) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start(
        inputSampleRate: Double,
        outputSampleRate: Double,
        onInputAudio: @escaping @Sendable (Data) -> Void
    ) throws {
        stop()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let inputPCMFormat = pcm16Format(sampleRate: inputSampleRate)
        let outputPCMFormat = pcm16Format(sampleRate: outputSampleRate)
        guard let converter = AVAudioConverter(
            from: inputFormat,
            to: inputPCMFormat
        ) else {
            throw RealtimeAudioEngineError.converterUnavailable
        }
        inputConverter = converter
        self.inputPCMFormat = inputPCMFormat
        self.outputPCMFormat = outputPCMFormat

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: outputPCMFormat)

        inputNode.installTap(
            onBus: 0,
            bufferSize: 2048,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let data = self?.convertInputBuffer(buffer) else { return }
            onInputAudio(data)
        }

        try engine.start()
        playerNode.play()
    }

    func play(_ pcm16Audio: Data) {
        guard !pcm16Audio.isEmpty,
              let buffer = makePlaybackBuffer(from: pcm16Audio)
        else { return }

        if !playerNode.isPlaying {
            playerNode.play()
        }
        playerNode.scheduleBuffer(buffer)
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        inputConverter = nil
    }

    private func convertInputBuffer(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let inputConverter,
              let inputPCMFormat
        else { return nil }

        let ratio = inputPCMFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: inputPCMFormat,
            frameCapacity: capacity
        ) else { return nil }

        var didProvideInput = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        var error: NSError?
        inputConverter.convert(
            to: convertedBuffer,
            error: &error,
            withInputFrom: inputBlock
        )
        guard error == nil else { return nil }
        return pcm16Data(from: convertedBuffer)
    }

    private func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let int16ChannelData = buffer.int16ChannelData else { return nil }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let byteCount = frameLength * max(channelCount, 1) * MemoryLayout<Int16>.size
        return Data(bytes: int16ChannelData[0], count: byteCount)
    }

    private func makePlaybackBuffer(from data: Data) -> AVAudioPCMBuffer? {
        guard let outputPCMFormat else { return nil }
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: outputPCMFormat,
            frameCapacity: frameCount
        ) else { return nil }

        buffer.frameLength = frameCount
        guard let destination = buffer.int16ChannelData?[0] else { return nil }
        data.withUnsafeBytes { rawBuffer in
            if let source = rawBuffer.bindMemory(to: Int16.self).baseAddress {
                destination.update(from: source, count: Int(frameCount))
            }
        }
        return buffer
    }
}

enum RealtimeAudioEngineError: LocalizedError {
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .converterUnavailable:
            return "Ses dönüştürücü başlatılamadı."
        }
    }
}
