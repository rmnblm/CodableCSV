/// Separators scalars/strings.
public enum Delimiter {
  /// The CSV pair of delimiters (field & row delimiters).
  public typealias Pair = (field: Self.Field, row: Self.Row)
  
  public typealias WriterPair = (field: [Unicode.Scalar], row: [Unicode.Scalar])
}

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

extension Delimiter {
  /// The delimiter between fields/values.
  ///
  /// If the delimiter is initialized with `nil`, it implies the field delimiter is unknown and the system should try to figure it out.
  public struct Field: ExpressibleByNilLiteral, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The accepted field delimiter. Usually a comma `,`.
    let delimiter: Self._Delimiter

    init(delimiter: Self._Delimiter) {
      self.delimiter = delimiter
    }

    public init(nilLiteral: ()) {
      self.delimiter = .infer(options: [",", ";", "\t"])
    }

    public init(unicodeScalarLiteral value: Unicode.Scalar) {
      self.delimiter = .use(.init(unicodeScalarLiteral: value))
    }

    public init(stringLiteral value: String) {
      self.delimiter = .use(.init(stringLiteral: value))
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

    /// Automatically infer the field delimiter out of a list of the most common delimiters: comma (","), semicolon (";") and tab ("\t").
    public static var infer: Self {
      self.init(nilLiteral: ())
    }

    /// Automatically infer the field delimiter out of a list of provided delimiters.
    /// - parameter options: The possible delimiters
    /// - returns: An instance of `Self` initialized for inference
    public static func infer(options: [Delimiter_]) -> Self {
      precondition(!options.isEmpty)
      // TODO: Figure out what to do when `options` contains the same delimiter multiple times
      return self.init(delimiter: .infer(options: options))
    }

    enum _Delimiter {
      case use(Delimiter_)
      case infer(options: [Delimiter_])
    }
  }
}

extension Delimiter {
  /// The delimiter between rows.
  ///
  /// If the delimiter is initialized with `nil`, it implies the row delimiter is unknown and the system should try to figure it out.
  public struct Row: ExpressibleByStringLiteral, ExpressibleByNilLiteral, CustomStringConvertible {
    /// All the accepted row delimiters. Usually, it is only one.
    /// - invariant: The elements of the set (i.e. the arrays) always contain at least one element.
    let delimiter: Self._Delimiter

    init(delimiter: Self._Delimiter) {
      self.delimiter = delimiter
    }

    public init(nilLiteral: ()) {
      self.delimiter = .infer(options: ["\n", "\r\n"])
    }

    public init(unicodeScalarLiteral value: Unicode.Scalar) {
      var delimiters = Set<Delimiter_>(minimumCapacity: 1)
      delimiters.insert(.init(unicodeScalarLiteral: value))
      self.delimiter = .use(RowDelimiterSet(rowDelimiterSet: delimiters))
    }

    public init(stringLiteral value: String) {
      var delimiters = Set<Delimiter_>(minimumCapacity: 1)
      delimiters.insert(.init(stringLiteral: value))
      self.delimiter = .use(RowDelimiterSet(rowDelimiterSet: delimiters))
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

    public static var infer: Self {
      self.init(nilLiteral: ())
    }

    /// Automatically infer the field delimiter out of a list of provided delimiters.
    /// - parameter options: The possible delimiters, must not be empty
    /// - returns: An instance of `Self` initialized for inference
    public static func infer(options: [Delimiter_]) -> Self {
      precondition(!options.isEmpty)
      // TODO: Figure out what to do when `options` contains the same delimiter multiple times
      return self.init(delimiter: .infer(options: options))
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

extension Delimiter {
  /// Contains the exact composition of a CSV field and row delimiter.
  public struct Scalars {
    /// The exact composition of unicode scalars indetifying a field delimiter.
    /// - invariant: The array always contains at least one element.
    let field: Delimiter_
    /// All possile row delimiters specifying its exact compositon of unicode scalars.
    /// - invariant: The set always contains at least one element and all set elements always contain at least on scalar.
    let row: RowDelimiterSet

    /// Designated initializer checking that the delimiters aren't empty and the field delimiter is not included in the row delimiter.
    /// - parameter field: The exact composition of the field delimiter. If empty, `nil` is returned.
    /// - parameter row: The exact composition of all possible row delimiters. If it is empty or any of its elements is an empty array, `nil` is returned.
    public init(field: Delimiter_, row: RowDelimiterSet) {
      self.field = field
//      guard !row.isEmpty, row.allSatisfy({ !$0.isEmpty }) else { return nil }
      self.row = row
//      guard self.row.allSatisfy({ $0 != self.field }) else { return nil }
    }
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
