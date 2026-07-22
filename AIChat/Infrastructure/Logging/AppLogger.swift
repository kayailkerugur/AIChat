//
//  AppLogger.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Thin os.Logger namespace. Category per layer so Console.app
//  filtering stays useful.
//
//  SECURITY RULE (spec §6.2): tokens, API keys, auth codes and raw
//  HTTP bodies must NEVER be interpolated into log messages — log
//  event names and error descriptions only. os.Logger already
//  redacts dynamic values by default; do not mark sensitive values
//  as `.public`.
//

import Foundation
import os

enum AppLogger {

    private static let subsystem =
        Bundle.main.bundleIdentifier ?? "com.aichat.app"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let auth        = Logger(subsystem: subsystem, category: "auth")
    static let ui          = Logger(subsystem: subsystem, category: "ui")
}
