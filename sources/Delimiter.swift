public struct Delimiter: Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
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

extension Delimiter: Sequence {
  public func makeIterator() -> Array<Element>.Iterator {
    self.scalars.makeIterator()
  }
}

extension Delimiter: Collection {
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
  public typealias Pair = (field: Self, row: Self)
}

protocol InferrableDelimiter: ExpressibleByNilLiteral, ExpressibleByStringLiteral {
  static var defaultInferenceOptions: [Delimiter] { get }
  static func infer(options: [Delimiter]) -> Self

  init(delimiter: Delimiter)
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

public struct RowDelimiterSet: ExpressibleByArrayLiteral, ExpressibleByStringLiteral {
  let rowDelimiterSet: Set<Delimiter>

  public init(rowDelimiterSet: Set<Delimiter>) {
    precondition(!rowDelimiterSet.isEmpty)
    self.rowDelimiterSet = rowDelimiterSet
  }

  public init(arrayLiteral elements: Delimiter...) {
    self.init(rowDelimiterSet: Set(elements))
  }

  public init(stringLiteral value: String) {
    self.init(rowDelimiterSet: Set([Delimiter(stringLiteral: value)]))
  }
}

extension RowDelimiterSet: Hashable {}
