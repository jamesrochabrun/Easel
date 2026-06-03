//
//  ProjectResourceCodeLanguageMapper.swift
//  EaselChat
//

import Foundation
import HighlightSwift

protocol ProjectResourceCodeLanguageMapping {
  func highlightMode(forFileName fileName: String) -> HighlightMode
  func displayName(forFileName fileName: String) -> String?
}

struct ProjectResourceCodeLanguageMapper: ProjectResourceCodeLanguageMapping {
  func highlightMode(forFileName fileName: String) -> HighlightMode {
    guard let language = normalizedLanguage(forFileName: fileName) else {
      return .automatic
    }

    if let highlightLanguage = highlightLanguage(for: language) {
      return .languageIgnoreIllegal(highlightLanguage)
    }

    return .languageAliasIgnoreIllegal(language)
  }

  func displayName(forFileName fileName: String) -> String? {
    guard let language = normalizedLanguage(forFileName: fileName) else {
      return nil
    }

    switch language {
    case "js", "jsx":
      return "javascript"
    case "ts", "tsx":
      return "typescript"
    case "py":
      return "python"
    case "rb":
      return "ruby"
    case "rs":
      return "rust"
    case "kt":
      return "kotlin"
    case "sh", "zsh", "bash":
      return "shell"
    case "yml":
      return "yaml"
    case "md":
      return "markdown"
    case "objc", "objectivec":
      return "objective-c"
    case "cs", "csharp":
      return "c#"
    case "cpp", "cxx", "c++":
      return "c++"
    default:
      return language
    }
  }

  private func normalizedLanguage(forFileName fileName: String) -> String? {
    let lastPathComponent = (fileName as NSString).lastPathComponent.lowercased()

    if let specialLanguage = languageForSpecialFileName(lastPathComponent) {
      return specialLanguage
    }

    let fileExtension = (lastPathComponent as NSString).pathExtension.lowercased()
    guard !fileExtension.isEmpty else {
      return nil
    }

    switch fileExtension {
    case "htm":
      return "html"
    case "c++":
      return "cpp"
    case "h":
      return "c"
    case "hpp":
      return "cpp"
    case "m", "mm":
      return "objective-c"
    case "plist", "xhtml":
      return "xml"
    case "csv", "log", "tsv", "txt":
      return "plaintext"
    default:
      return fileExtension
    }
  }

  private func languageForSpecialFileName(_ fileName: String) -> String? {
    switch fileName {
    case "dockerfile":
      return "dockerfile"
    case "makefile":
      return "makefile"
    case "gemfile", "podfile", "rakefile":
      return "ruby"
    case ".bash_profile", ".bashrc", ".profile", ".zprofile", ".zshrc":
      return "shell"
    default:
      return nil
    }
  }

  private func highlightLanguage(for language: String) -> HighlightLanguage? {
    switch language {
    case "applescript":
      return .appleScript
    case "arduino":
      return .arduino
    case "awk":
      return .awk
    case "bash":
      return .bash
    case "basic":
      return .basic
    case "c":
      return .c
    case "cpp", "c++", "cxx":
      return .cPlusPlus
    case "csharp", "c#", "cs":
      return .cSharp
    case "clojure", "clj":
      return .clojure
    case "css":
      return .css
    case "dart":
      return .dart
    case "delphi":
      return .delphi
    case "diff", "patch":
      return .diff
    case "django":
      return .django
    case "dockerfile", "docker":
      return .dockerfile
    case "elixir", "ex":
      return .elixir
    case "elm":
      return .elm
    case "erlang", "erl":
      return .erlang
    case "gherkin":
      return .gherkin
    case "go", "golang":
      return .go
    case "gradle":
      return .gradle
    case "graphql", "gql":
      return .graphQL
    case "haskell", "hs":
      return .haskell
    case "html", "xml":
      return .html
    case "java":
      return .java
    case "javascript", "js", "jsx":
      return .javaScript
    case "json":
      return .json
    case "julia":
      return .julia
    case "kotlin", "kt":
      return .kotlin
    case "latex", "tex":
      return .latex
    case "less":
      return .less
    case "lisp":
      return .lisp
    case "lua":
      return .lua
    case "makefile", "make":
      return .makefile
    case "markdown", "md":
      return .markdown
    case "mathematica":
      return .mathematica
    case "matlab":
      return .matlab
    case "nix":
      return .nix
    case "objc", "objective-c", "objectivec":
      return .objectiveC
    case "perl":
      return .perl
    case "php":
      return .php
    case "plaintext", "text", "txt":
      return .plaintext
    case "postgres", "postgresql":
      return .postgreSQL
    case "protobuf", "protocolbuffers":
      return .protocolBuffers
    case "python", "py":
      return .python
    case "python-repl":
      return .pythonRepl
    case "r":
      return .r
    case "ruby", "rb":
      return .ruby
    case "rust", "rs":
      return .rust
    case "scala":
      return .scala
    case "scss":
      return .scss
    case "shell", "sh", "zsh":
      return .shell
    case "sql":
      return .sql
    case "swift":
      return .swift
    case "toml":
      return .toml
    case "typescript", "ts", "tsx":
      return .typeScript
    case "vb", "vbnet":
      return .visualBasic
    case "wasm", "webassembly":
      return .webAssembly
    case "yaml", "yml":
      return .yaml
    default:
      return nil
    }
  }
}
