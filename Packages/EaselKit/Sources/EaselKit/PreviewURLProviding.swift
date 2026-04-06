//
//  PreviewURLProviding.swift
//  EaselKit
//

import Foundation

@MainActor
public protocol PreviewURLProviding: AnyObject {
  var previewURL: URL? { get }
}
