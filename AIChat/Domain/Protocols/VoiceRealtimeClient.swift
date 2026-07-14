//
//  VoiceRealtimeClient.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import Foundation

protocol VoiceRealtimeClient: AnyObject {
    var inputSampleRate: Double { get }
    var outputSampleRate: Double { get }

    func connect() -> AsyncStream<VoiceRealtimeEvent>
    func sendAudio(_ pcm16Audio: Data) async
    func disconnect()
}
