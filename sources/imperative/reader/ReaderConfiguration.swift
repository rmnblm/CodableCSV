import Foundation

extension CSVReader {
  /// Configuration for how to read CSV data.
  public struct Configuration {
    /// The encoding used to identify the underlying data or `nil` if you want the CSV reader to try to figure it out.
    ///
    /// If no encoding is provided and the input data doesn't contain a Byte Order Marker (BOM), UTF8 is presumed.
    public var encoding: String.Encoding?
    /// The field and row delimiters.
    public var delimiters: Delimiters
    /// The strategy to allow/disable escaped fields and how.
    public var escapingStrategy: Strategy.Escaping
    /// Indication on whether the CSV will contain a header row or not, or that information is unknown and it should try to be inferred.
    public var headerStrategy: Strategy.Header
    /// Trims the given characters at the beginning and end of each row, and between fields.
    public var trimStrategy: CharacterSet
    /// Boolean indicating whether the data/file/string should be completely parsed at reader's initialization.
    public var presample: Bool

    /// Designated initializer setting the default values.
    public init() {
      self.encoding = nil
      self.delimiters = (field: ",", row: "\n")
      self.escapingStrategy = .doubleQuote
      self.headerStrategy = .none
      self.trimStrategy = CharacterSet()
      self.presample = false
    }
  }
}

extension Strategy {
  /// Indication on whether the CSV file contains headers or not.
  public enum Header: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral {
    /// The CSV contains no header row.
    case none
    /// The CSV contains a single header row.
    case firstLine
//    /// It is not known whether the CSV contains a header row. The library will try to infer it!
//    case unknown

    public init(nilLiteral: ()) {
      self = .none
    }

    public init(booleanLiteral value: BooleanLiteralType) {
      self = (value) ? .firstLine : .none
    }
  }
}

extension CSVReader.Configuration {
  /// The delimiter between fields/values.
  ///
  /// If the delimiter is initialized with `nil`, it implies the field delimiter is unknown and the system should try to figure it out.
  public struct FieldDelimiter {
    /// The accepted field delimiter. Usually a comma `,`.
    let delimiter: Self._Delimiter

    init(delimiter: Self._Delimiter) {
      self.delimiter = delimiter
    }

    /// The field delimiter is represented by the given `String`-like type.
    /// - parameter delimiter: The exact composition of the field delimiter. If empty, the initializer fails returning `nil`.
    public init?<S:StringProtocol>(_ delimiter: S) {
      guard let fieldDelimiter = Delimiter.init(delimiter)
      else { return nil }

      self.delimiter = .use(fieldDelimiter)
    }

    enum _Delimiter {
      case use(Delimiter)
      case infer(options: [Delimiter])
    }
  }
}

extension CSVReader.Configuration.FieldDelimiter: InferrableDelimiter {
  static var defaultInferenceOptions: [Delimiter] {
    [",", ";", "\t"]
  }

  init(delimiter: Delimiter) {
    self.delimiter = .use(delimiter)
  }

  public static func infer(options: [Delimiter]) -> Self {
    precondition(!options.isEmpty)
    // TODO: Figure out what to do when `options` contains the same delimiter multiple times
    return self.init(delimiter: .infer(options: options))
  }
}

extension CSVReader.Configuration {
  /// The delimiter between rows.
  ///
  /// If the delimiter is initialized with `nil`, it implies the row delimiter is unknown and the system should try to figure it out.
  public struct RowDelimiter: ExpressibleByStringLiteral {
    /// All the accepted row delimiters. Usually, it is only one.
    /// - invariant: The elements of the set (i.e. the arrays) always contain at least one element.
    let delimiter: Self._Delimiter

    init(delimiter: Self._Delimiter) {
      self.delimiter = delimiter
    }

    /// Creates one or more possible row delimiters.
    /// - parameter delimiters:The exact composition of the row delimiters. If any of the `delimiters` is empty, the initializer fails returning `nil`.
    public init?<S:StringProtocol>(_ delimiters: S...) {
      let scalars: [Delimiter] = delimiters.compactMap {
        guard !$0.isEmpty else { return nil }
        return Delimiter(scalars: Array($0.unicodeScalars))
      }
      guard !scalars.isEmpty else { return nil }
      self.delimiter = .use(RowDelimiterSet(rowDelimiterSet: Set(scalars)))
    }

    /// Specifies two row delimiters: CR (Carriage Return) LF (Line Feed) `\r\n` and s single line feed `\n`.
    ///
    /// This delimiter is intended to be used with CSVs where the end of the row may be marked with a CRLF sometimes and other times with LF.
    public static var standard: Self {
      self.init("\n", "\r\n")!
    }

    enum _Delimiter {
      case use(RowDelimiterSet)
      case infer(options: [Delimiter])
    }
  }
}

extension CSVReader.Configuration.RowDelimiter: InferrableDelimiter {
  static var defaultInferenceOptions: [Delimiter] {
    ["\n", "\r\n"]
  }

  init(delimiter: Delimiter) {
    var delimiters = Set<Delimiter>(minimumCapacity: 1)
    delimiters.insert(delimiter)
    self.delimiter = .use(RowDelimiterSet(rowDelimiterSet: delimiters))
  }

  public static func infer(options: [Delimiter]) -> Self {
    precondition(!options.isEmpty)
    return self.init(delimiter: .infer(options: options))
  }
}

extension CSVReader.Configuration {
  public typealias Delimiters = (field: Self.FieldDelimiter, row: Self.RowDelimiter)
}
