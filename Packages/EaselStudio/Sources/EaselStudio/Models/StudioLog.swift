import os

/// Package-local logger for Studio services.
enum StudioLog {
  static let logger = Logger(subsystem: "com.easel.studio", category: "studio")
}
