/// Separators scalars/strings.
//public enum Delimiter {
//  /// The CSV pair of delimiters (field & row delimiters).
//  public typealias Pair = (field: Self.Field, row: Self.Row)
//}

public struct Delimiter_: Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
  let scalars: [Unicode.Scalar]

  public init(scalars: [Unicode.Scalar]) {
    precondition(!scalars.isEmpty)
    self.scalars = scalars
  }

  public init(stringLiteral value: String) {
    self.init(scalars: Array(value.unicodeScalars))
  }

  public init(unicodeScalarLiteral value: Unicode.Scalar) {
    self.scalars = [value]
  }

  public init?<S:StringProtocol>(_ delimiter: S) {
    guard !delimiter.isEmpty else { return nil }
    self.init(scalars: Array(delimiter.unicodeScalars))
  }

  public var description: String {
    String(String.UnicodeScalarView(self.scalars))
  }
}

extension Delimiter_: Sequence {
  public func makeIterator() -> Array<Element>.Iterator {
    self.scalars.makeIterator()
  }
}

extension Delimiter_: Collection {
  public typealias Element = Unicode.Scalar
  public typealias Index = Array<Element>.Index

  public subscript(position: Index) -> Element {
    self.scalars[position]
  }

  public var startIndex: Index {
    self.scalars.startIndex
  }

  public var endIndex: Index {
    self.scalars.endIndex
  }

  public func index(after i: Index) -> Index {
    self.scalars.index(after: i)
  }
}

extension Delimiter_ {
  public typealias Pair = (field: Self, row: Self)
}

protocol InferrableDelimiter: ExpressibleByNilLiteral, ExpressibleByStringLiteral {
  static var defaultInferenceOptions: [Delimiter_] { get }
  static func infer(options: [Delimiter_]) -> Self

  init(delimiter: Delimiter_)
}

extension InferrableDelimiter {
  // Default conformance to ExpressibleByNilLiteral
  public init(nilLiteral: ()) {
    self = .infer
  }

  // Default conformance to ExpressibleByStringLiteral
  public init(unicodeScalarLiteral value: Unicode.Scalar) {
    self.init(delimiter: .init(unicodeScalarLiteral: value))
  }

  public init(stringLiteral value: String) {
    self.init(delimiter: .init(stringLiteral: value))
  }

  public static var infer: Self {
    Self.infer(options: Self.defaultInferenceOptions)
  }
}

extension CSVReader.Configuration {
  /// The delimiter between fields/values.
  ///
  /// If the delimiter is initialized with `nil`, it implies the field delimiter is unknown and the system should try to figure it out.
  public struct FieldDelimiter: CustomStringConvertible {
    /// The accepted field delimiter. Usually a comma `,`.
    let delimiter: Self._Delimiter

    init(delimiter: Self._Delimiter) {
      self.delimiter = delimiter
    }

    /// The field delimiter is represented by the given `String`-like type.
    /// - parameter delimiter: The exact composition of the field delimiter. If empty, the initializer fails returning `nil`.
    public init?<S:StringProtocol>(_ delimiter: S) {
      guard let fieldDelimiter = Delimiter_.init(delimiter)
      else { return nil }

      self.delimiter = .use(fieldDelimiter)
    }

    /// Returns the `String` representation of the field delimiter.
    public var description: String {
      ""
//      String(String.UnicodeScalarView(self.scalars))
    }

    var scalars: [Unicode.Scalar] {
      switch self.delimiter {
      case .infer:
        return []
      case let .use(fieldDelimiter):
        return fieldDelimiter.scalars
      }
    }

    enum _Delimiter {
      case use(Delimiter_)
      case infer(options: [Delimiter_])
    }
  }
}

extension CSVReader.Configuration.FieldDelimiter: InferrableDelimiter {
  static var defaultInferenceOptions: [Delimiter_] {
    [",", ";", "\t"]
  }

  init(delimiter: Delimiter_) {
    //    self.delimiter = .use(delimiter)
    self.init(delimiter: .use(delimiter))
  }

  /// Automatically infer the field delimiter out of a list of provided delimiters.
  /// - parameter options: The possible delimiters
  /// - returns: An instance of `Self` initialized for inference
  public static func infer(options: [Delimiter_]) -> Self {
    precondition(!options.isEmpty)
    // TODO: Figure out what to do when `options` contains the same delimiter multiple times
    return self.init(delimiter: .infer(options: options))
  }
}

extension CSVReader.Configuration {
  /// The delimiter between rows.
  ///
  /// If the delimiter is initialized with `nil`, it implies the row delimiter is unknown and the system should try to figure it out.
  public struct RowDelimiter: ExpressibleByStringLiteral, CustomStringConvertible {
    /// All the accepted row delimiters. Usually, it is only one.
    /// - invariant: The elements of the set (i.e. the arrays) always contain at least one element.
    let delimiter: Self._Delimiter

    init(delimiter: Self._Delimiter) {
      self.delimiter = delimiter
    }

    /// Creates one or more possible row delimiters.
    /// - parameter delimiters:The exact composition of the row delimiters. If any of the `delimiters` is empty, the initializer fails returning `nil`.
    public init?<S:StringProtocol>(_ delimiters: S...) {
      let scalars: [Delimiter_] = delimiters.compactMap {
        guard !$0.isEmpty else { return nil }
        return Delimiter_(scalars: Array($0.unicodeScalars))
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

    var scalars: Set<[Unicode.Scalar]> {
      switch self.delimiter {
      case .infer:
        return []
      case let .use(rowDelimiter):
        return Set(rowDelimiter.rowDelimiterSet.map(\.scalars))
      }
    }

    /// Returns the `String` representation of the row delimiter.
    ///
    /// If more than one row has been provided, the `String` with less number of characters and less value (i.e. less Integer value) is selected.
    public var description: String {
      ""
//      String(String.UnicodeScalarView(self.scalars.min {
//        guard $0.count == $1.count else { return $0.count < $1.count }
//        for (lhs, rhs) in zip($0, $1) where lhs != rhs { return lhs < rhs }
//        return true
//      }!))
    }

    enum _Delimiter {
      case use(RowDelimiterSet)
      case infer(options: [Delimiter_])
    }
  }
}

extension CSVReader.Configuration.RowDelimiter: InferrableDelimiter {
  static var defaultInferenceOptions: [Delimiter_] {
    ["\n", "\r\n"]
  }

  init(delimiter: Delimiter_) {
    var delimiters = Set<Delimiter_>(minimumCapacity: 1)
    delimiters.insert(delimiter)
    self.delimiter = .use(RowDelimiterSet(rowDelimiterSet: delimiters))
  }

  /// Automatically infer the field delimiter out of a list of provided delimiters.
  /// - parameter options: The possible delimiters, must not be empty
  /// - returns: An instance of `Self` initialized for inference
  public static func infer(options: [Delimiter_]) -> Self {
    precondition(!options.isEmpty)
    // TODO: Figure out what to do when `options` contains the same delimiter multiple times
    return self.init(delimiter: .infer(options: options))
  }
}

public struct RowDelimiterSet: ExpressibleByArrayLiteral, ExpressibleByStringLiteral {
  let rowDelimiterSet: Set<Delimiter_>

  public init(rowDelimiterSet: Set<Delimiter_>) {
    precondition(!rowDelimiterSet.isEmpty)
    self.rowDelimiterSet = rowDelimiterSet
  }

  public init(arrayLiteral elements: Delimiter_...) {
    self.init(rowDelimiterSet: Set(elements))
  }

  public init(stringLiteral value: String) {
    self.init(rowDelimiterSet: Set([Delimiter_(stringLiteral: value)]))
  }
}

extension RowDelimiterSet: Hashable {}
