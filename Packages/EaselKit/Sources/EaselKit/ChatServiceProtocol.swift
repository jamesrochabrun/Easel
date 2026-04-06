//
//  ChatServiceProtocol.swift
//  EaselKit
//

import Foundation

@MainActor
public protocol ChatServiceProtocol: AnyObject {
  func sendMessage(_ text: String, context: String?, hiddenContext: String?)
}
