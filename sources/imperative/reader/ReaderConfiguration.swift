import Foundation

extension CSVReader {
  /// Configuration for how to read CSV data.
  public struct Configuration {
    /// The encoding used to identify the underlying data or `nil` if you want the CSV reader to try to figure it out.
    ///
    /// If no encoding is provided and the input data doesn't contain a Byte Order Marker (BOM), UTF8 is presumed.
    public var encoding: String.Encoding?
    /// The field and row delimiters.
    public var delimiters: Self.Delimiters
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

// MARK: - Delimiters

extension CSVReader.Configuration {
  public typealias Delimiters = (field: Self.FieldDelimiter, row: Self.RowDelimiter)

  public struct FieldDelimiter {
    let inferenceConfiguration: InferenceConfiguration<Delimiter>
  }

  public struct RowDelimiter {
    let inferenceConfiguration: InferenceConfiguration<Set<Delimiter>>
  }

  enum InferenceConfiguration<T> {
    case use(T)
    case infer(options: [Delimiter])
  }
}

// MARK: FieldDelimiter extensions

extension CSVReader.Configuration.FieldDelimiter {
  /// The field delimiter is represented by the given `String`-like type.
  /// - parameter delimiter: The exact composition of the field delimiter. If empty, the initializer fails returning `nil`.
  public init?<S:StringProtocol>(_ delimiter: S) {
    guard let fieldDelimiter = Delimiter.init(delimiter)
    else { return nil }

    self.inferenceConfiguration = .use(fieldDelimiter)
  }
}

extension CSVReader.Configuration.FieldDelimiter: DelimiterProtocol {
  init(delimiter: Delimiter) {
    self.inferenceConfiguration = .use(delimiter)
  }
}

extension CSVReader.Configuration.FieldDelimiter: Inferrable {
  public static var defaultInferenceOptions: [Delimiter] {
    [",", ";", "\t"]
  }

  public static func infer(options: [Delimiter]) -> Self {
    self.init(inferenceConfiguration: .infer(options: options))
  }
}

// MARK: RowDelimiter extensions

extension CSVReader.Configuration.RowDelimiter {
  /// Creates one or more possible row delimiters.
  /// - parameter delimiters:The exact composition of the row delimiters. If any of the `delimiters` is empty, the initializer fails returning `nil`.
  public init?<S:StringProtocol>(_ delimiters: S...) {
    let delimiters: [Delimiter] = delimiters.compactMap {
      guard !$0.isEmpty else { return nil }
      return Delimiter(scalars: Array($0.unicodeScalars))
    }
    guard !delimiters.isEmpty else { return nil }
    self.inferenceConfiguration = .use(Set(delimiters))
  }

  /// Specifies two row delimiters: CR (Carriage Return) LF (Line Feed) `\r\n` and a single line feed `\n`.
  ///
  /// This delimiter is intended to be used with CSVs where the end of the row may be marked with a CRLF sometimes and other times with LF.
  public static var standard: Self {
    self.init(inferenceConfiguration: .use(["\n", "\r\n"]))
  }
}

extension CSVReader.Configuration.RowDelimiter: DelimiterProtocol {
  init(delimiter: Delimiter) {
    var delimiters = Set<Delimiter>(minimumCapacity: 1)
    delimiters.insert(delimiter)
    self.inferenceConfiguration = .use(delimiters)
  }
}

extension CSVReader.Configuration.RowDelimiter: Inferrable {
  public static var defaultInferenceOptions: [Delimiter] {
    ["\n", "\r\n"]
  }

  public static func infer(options: [Delimiter]) -> Self {
    self.init(inferenceConfiguration: .infer(options: options))
  }
}
