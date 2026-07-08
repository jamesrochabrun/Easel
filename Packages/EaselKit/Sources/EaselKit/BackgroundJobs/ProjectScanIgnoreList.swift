//
//  ProjectScanIgnoreList.swift
//  EaselKit
//
//  Directory names excluded from project scans. Shared by the preview
//  file-change observers and the background-job shadow workspace so drift
//  detection and apply scope stay in lockstep with what observers watch.
//

// MARK: - ProjectScanIgnoreList

public enum ProjectScanIgnoreList {
  public static let directoryNames: Set<String> = [
    ".git",
    ".svn",
    ".swiftpm",
    ".build",
    ".easel",
    ".cache",
    ".next",
    ".nuxt",
    ".turbo",
    ".vercel",
    "DerivedData",
    "build",
    "coverage",
    "dist",
    "node_modules",
    "out",
  ]
}
