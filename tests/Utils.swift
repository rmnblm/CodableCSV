@testable import CodableCSV

extension CSVReader.Configuration.FieldDelimiter: CustomStringConvertible {
  public var description: String {
    guard case .use(let delimiter) = self.inferenceConfiguration
    else { fatalError() }

    return delimiter.description
  }
}

extension CSVReader.Configuration.FieldDelimiter {
  var scalars: [Unicode.Scalar] {
    switch self.inferenceConfiguration {
    case .infer:
      return []
    case let .use(fieldDelimiter):
      return fieldDelimiter.scalars
    }
  }
}

extension CSVReader.Configuration.RowDelimiter: CustomStringConvertible {
  public var description: String {
    guard case .use(let r) = self.inferenceConfiguration
    else { fatalError() }

    return r.first!.description
  }
}

extension CSVReader.Configuration.RowDelimiter {
  var scalars: Set<[Unicode.Scalar]> {
    switch self.inferenceConfiguration {
    case .infer:
      return []
    case let .use(rowDelimiter):
      return Set(rowDelimiter.map(\.scalars))
    }
  }
}
