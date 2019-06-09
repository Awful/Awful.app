import Foundation


extension String {
  /// Split a string by a separator leaving quoted phrases together
  func smartSplit(separator: Character = " ") -> [String] {
    var word = ""
    var components: [String] = []
    var separate: Character = separator
    var singleQuoteCount = 0
    var doubleQuoteCount = 0

    let specialCharacters = ",|:"
    func appendWord(_ word: String) {
      if components.count > 0 {
        if let precedingChar = components.last?.last, specialCharacters.contains(precedingChar) {
          components[components.count-1] += word
        } else if specialCharacters.contains(word) {
          components[components.count-1] += word
        } else {
          components.append(word)
        }
      } else {
        components.append(word)
      }
    }

    for character in self {
      if character == "'" { singleQuoteCount += 1 }
      else if character == "\"" { doubleQuoteCount += 1 }

      if character == separate {

        if separate != separator {
          word.append(separate)
        } else if (singleQuoteCount % 2 == 0 || doubleQuoteCount % 2 == 0) && !word.isEmpty {
          appendWord(word)
          word = ""
        }

        separate = separator
      } else {
        if separate == separator && (character == "'" || character == "\"") {
          separate = character
        }
        word.append(character)
      }
    }

    if !word.isEmpty {
      appendWord(word)
    }

    return components
  }
}

public struct SourceMap: Equatable {
  public let filename: String?
  public let location: ContentLocation

  init(filename: String? = nil, location: ContentLocation = ("", 0, 0)) {
    self.filename = filename
    self.location = location
  }

  static let unknown = SourceMap()

  public static func ==(lhs: SourceMap, rhs: SourceMap) -> Bool {
    return lhs.filename == rhs.filename && lhs.location == rhs.location
  }
}

public enum Token : Equatable {
  /// A token representing a piece of text.
  case text(value: String, at: SourceMap)

  /// A token representing a variable.
  case variable(value: String, at: SourceMap)

  /// A token representing a comment.
  case comment(value: String, at: SourceMap)

  /// A token representing a template block.
  case block(value: String, at: SourceMap)

  /// Returns the underlying value as an array seperated by spaces
  public func components() -> [String] {
    switch self {
    case .block(let value, _),
         .variable(let value, _),
         .text(let value, _),
         .comment(let value, _):
      return value.smartSplit()
    }
  }

  public var contents: String {
    switch self {
    case .block(let value, _),
         .variable(let value, _),
         .text(let value, _),
         .comment(let value, _):
      return value
    }
  }

  public var sourceMap: SourceMap {
    switch self {
    case .block(_, let sourceMap),
         .variable(_, let sourceMap),
         .text(_, let sourceMap),
         .comment(_, let sourceMap):
      return sourceMap
    }
  }
}
