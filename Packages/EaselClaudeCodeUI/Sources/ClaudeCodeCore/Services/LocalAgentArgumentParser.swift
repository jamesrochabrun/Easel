//
//  LocalAgentArgumentParser.swift
//  ClaudeCodeUI
//

import Foundation

public enum LocalAgentArgumentParser {
  public static func parse(_ value: String) -> [String] {
    var arguments: [String] = []
    var current = ""
    var quote: Character?
    var escaping = false
    var hasCurrentArgument = false

    for character in value {
      if escaping {
        current.append(character)
        hasCurrentArgument = true
        escaping = false
        continue
      }

      if character == "\\" {
        escaping = true
        hasCurrentArgument = true
        continue
      }

      if let activeQuote = quote {
        if character == activeQuote {
          quote = nil
        } else {
          current.append(character)
          hasCurrentArgument = true
        }
        continue
      }

      if character == "'" || character == "\"" {
        quote = character
        hasCurrentArgument = true
        continue
      }

      if character.isWhitespace {
        if hasCurrentArgument {
          arguments.append(current)
          current = ""
          hasCurrentArgument = false
        }
        continue
      }

      current.append(character)
      hasCurrentArgument = true
    }

    if escaping {
      current.append("\\")
    }
    if hasCurrentArgument {
      arguments.append(current)
    }
    return arguments
  }
}
