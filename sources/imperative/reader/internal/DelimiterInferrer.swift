// Parts of the code in this file are adapted from the CleverCSV Python library.
// See: https://github.com/alan-turing-institute/CleverCSV

/*
 Copyright (c) 2018 The Alan Turing Institute

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

/// Provides the means for detecting a CSV file's dialect.
struct DelimiterInferrer {
  let dialects: [Dialect]

  init(possibleFieldDelimiters: [Delimiter], possibleRowDelimiters: [Set<Delimiter>]) throws {
    self.dialects = try Self.makeDialectCandidates(possibleFieldDelimiters, possibleRowDelimiters)
  }

  /// Generates a list of all possible delimiter combinations, maintaining the
  /// - parameter possibleFieldDelimiters: An array of possible field delimiters. Must not be empty.
  /// - parameter possibleRowDelimiters: An array of possible row delimiters. Must not be empty.
  /// - returns: The array of delimiter combinations.
  static func makeDialectCandidates(
    _ possibleFieldDelimiters: [Delimiter],
    _ possibleRowDelimiters: [Set<Delimiter>]
  ) throws -> [Dialect] {
    guard !possibleFieldDelimiters.isEmpty, !possibleRowDelimiters.isEmpty
    else { throw CSVReader.Error._emptyDelimiterOptions() }

    // 1. Generate all possible combinations of indices.
    // Example: (0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)
    let indexPairs = possibleFieldDelimiters.indices.flatMap { fieldIndex in
      possibleRowDelimiters.indices.map { rowIndex in
        (fieldIndex: fieldIndex, rowIndex: rowIndex)
      }
    }
    // 2. Sort index pairs by their sum, i.e. from most likely pairs to least likely pairs.
    // Example: (0, 0), (0, 1), (1, 0), (0, 2), (1, 1), (1, 2)
    let sortedIndexPairs = indexPairs.sorted { lhs, rhs in
      lhs.fieldIndex + lhs.rowIndex < rhs.fieldIndex + rhs.rowIndex
    }
    // 3. Use the indices to access the actual delimiters.
    let delimiterCombinations = sortedIndexPairs.map {
      (possibleFieldDelimiters[$0.fieldIndex], possibleRowDelimiters[$0.rowIndex])
    }
    // 4. Return only valid candidates.
    return try delimiterCombinations.map(Dialect.init(field:row:))
  }

  /// Detects the dialect used in the provided CSV file.
  ///
  ///	A dialect describes the way in which a CSV file is formatted, i.e. which field
  ///	delimiter, row delimiter and escape character is used.
  ///
  /// - Parameter stringScalars: The raw CSV data.
  /// - Returns: The detected dialect.
  func detectDialect(stringScalars: [UnicodeScalar]) -> Dialect? {
    var maxConsistency = -Double.infinity
    var scores: [Dialect: Double] = [:]

    for dialect in self.dialects {
      let patternScore = Self.calculatePatternScore(stringScalars: stringScalars, dialect: dialect)

      if patternScore < maxConsistency {
        // Skip the computation of the type score for dialects with a low pattern score.
        continue
      }
      // TODO: Calculate type score?
      let typeScore = 1.0
      let consistencyScore = patternScore * typeScore
      maxConsistency = max(maxConsistency, consistencyScore)
      scores[dialect] = consistencyScore
    }

    let best = scores.max { a, b in a.value < b.value }

    return best?.key
  }

  private static let eps = 0.001

  /// Calculates a score for the given dialect by anayzing the row patterns that result when interpreting the CSV data using that dialect.
  ///
  /// The correct dialect is expected to produce many rows of the same pattern
  /// The pattern score favors row patterns that occur often, that are long and favors having fewer row patterns.
  ///
  /// - parameter stringScalars: The raw CSV data.
  /// - parameter dialect: A dialect for which to calculate the score.
  /// - returns: The calculated pattern score for the given dialect.
  static func calculatePatternScore(stringScalars: [UnicodeScalar], dialect: Dialect) -> Double {
    guard let abstraction = Self.makeAbstraction(stringScalars: stringScalars, dialect: dialect)
    else { return 0.0 }

#warning("TODO: Break ties based on generated errors")

    let rowPatternCounts: [ArraySlice<Abstraction>: Int] = abstraction
      .split(separator: .rowDelimiter)
      .occurenceCounts()

    var score = 0.0
    for (rowPattern, count) in rowPatternCounts {
      let fieldCount = Double(rowPattern.split(separator: .fieldDelimiter).count)
      score += Double(count) * max(Self.eps, fieldCount - 1.0) / fieldCount
    }
    score /= Double(rowPatternCounts.count)

    return score
  }

  typealias Dialect = CSVReader.Settings.Delimiters
}

// MARK: -

extension DelimiterInferrer {
  /// An abstracted piece of CSV data
  enum Abstraction: Character, Hashable {
    case cell = "C", fieldDelimiter = "D", rowDelimiter = "R"

    /// The type of error raised by `makeAbstraction`.
    enum Error: Swift.Error {
      /// An escape character, e.g. a quote, occured in an invalid place.
      ///
      /// Example:
      /// ```
      /// foo,bar"wrong",baz
      /// ```
      case invalidEscapeCharacterPosition

      /// The last escaped field was not closed due to an uneven number of escape characters.
      ///
      /// Example:
      /// ```
      /// foo,bar,"baz
      /// ```
      case unbalancedEscapeCharacters
    }
  }

  static func makeAbstraction(stringScalars: [Unicode.Scalar], dialect: Dialect) -> [Abstraction]? {
    var configuration = CSVReader.Configuration()
    configuration.delimiters = (field: .init(inferenceConfiguration: .use(dialect.field)), row: .init(inferenceConfiguration: .use(dialect.row)))

    let iter = stringScalars.makeIterator()
    let buffer = CSVReader.ScalarBuffer(reservingCapacity: 110)
    let decoder = CSVReader.makeDecoder(from: iter)

    guard let reader = try? CSVReader(configuration: configuration, buffer: buffer, decoder: decoder)
    else { return nil }

    var abstraction: [[Abstraction]] = []
    while let row = try? reader.readRow() {
      let rowAbstraction: [Abstraction] = row.flatMap { _ in [.cell, .fieldDelimiter] }.dropLast()
      abstraction.append(rowAbstraction)
    }

    return Array(abstraction.joined(separator: [Abstraction.rowDelimiter]))
  }

  /// Builds an abstraction of the CSV data by parsing it with the provided dialect.
  ///
  /// For example, consider the following CSV data:
  /// ```
  /// one,two,three
  /// foo,funny ;),bar
  /// ```
  /// Assuming a field delimiter of `,` this produces the following abstraction:
  /// ```
  /// CDCDC
  /// CDCDC
  /// ```
  /// Here, `C` represents a cell (field) and `D` stands for a field delimiter.
  ///
  /// However when we instead consider `;` as the field delimiter, the following abstraction is produced:
  /// ```
  /// C
  /// CDC
  /// ```
  /// This abstraction can then be used to guess the delimiter, because the correct
  /// delimiter will produce an abstraction with many identical row patterns.
  ///
  /// - parameter stringScalars: The raw CSV data.
  /// - parameter dialect: The dialect to use for speculatively interpreting the CSV data.
  /// - throws: An `Abstraction.Error`.
  /// - returns: An array of cells and delimiters.
  /// - todo: Currently assuming that delimiters can only be made up of a single Unicode scalar.
//  static func makeAbstraction(stringScalars: [Unicode.Scalar], dialect: Dialect) -> ([Abstraction], [Abstraction.Error]) {
//    var abstraction: [Abstraction] = []
//    var errors: [Abstraction.Error] = []
//    var escaped = false
//
//    var iter = stringScalars.makeIterator()
//    var queuedNextScalar: Unicode.Scalar? = nil
//
//    let buffer = CSVReader.ScalarBuffer(reservingCapacity: 110)
//    let decoder = CSVReader.makeDecoder(from: iter)
//
//    let x = CSVReader.Configuration.Delimiter.Scalars._makeMatcher(delimiter: dialect.fieldDelimiter, buffer: buffer, decoder: decoder)
//
//
//    while let scalar = queuedNextScalar ?? iter.next() {
//      queuedNextScalar = nil
//
//      switch scalar {
//      case dialect.fieldDelimiter:
//        if escaped { continue }
//
//        switch abstraction.last {
//        // - two consecutive field delimiters OR
//        // - field delimiter after row delimiter, i.e. at start of line OR
//        // - field delimiter at the very beginning, i.e. at start of first line
//        // all imply an empty cell
//        case .fieldDelimiter, .rowDelimiter, nil:
//          abstraction.append(.cell)
//          fallthrough
//        case .cell:
//          abstraction.append(.fieldDelimiter)
//        }
//
//      case dialect.rowDelimiter:
//        if escaped { continue }
//
//        switch abstraction.last {
//        // - two consecutive row delimiters
//        // - row delimiter after field delimiter
//        // - row delimiter at the very beginning, i.e. at start of first line
//        // all imply an empty cell
//        case .rowDelimiter, .fieldDelimiter, nil:
//          abstraction.append(.cell)
//          fallthrough
//        case .cell:
//          abstraction.append(.rowDelimiter)
//        }
//
//      case dialect.escapeCharacter:
//        if !escaped {
//          if abstraction.last == .cell {
//            // encountered an escape character after the beginning of a field
//            errors.append(.invalidEscapeCharacterPosition)
//          }
//          escaped = true
//          continue
//        }
//
//        // we are in an escaped context, so the encountered escape character
//        // is either the end of the field or must be followed by another escape character
//        let nextScalar = iter.next()
//
//        switch nextScalar {
//        case dialect.escapeCharacter:
//          // the escape character was escaped
//          continue
//        case nil:
//          // end of file
//          escaped = false
//        case dialect.fieldDelimiter, dialect.rowDelimiter:
//          // end of field
//          escaped = false
//          queuedNextScalar = nextScalar
//        default:
//          // encountered a non-delimiter character after the field ended
//          errors.append(.invalidEscapeCharacterPosition)
//          escaped = false
//          queuedNextScalar = nextScalar
//        }
//
//      default:
//        switch abstraction.last {
//        case .cell:
//          continue
//        case .fieldDelimiter, .rowDelimiter, nil:
//          abstraction.append(.cell)
//        }
//      }
//    }
//
//    if abstraction.last == .fieldDelimiter {
//      abstraction.append(.cell)
//    }
//
//    if escaped {
//      // reached EOF without closing the last escaped field
//      errors.append(.unbalancedEscapeCharacters)
//    }
//
//    return (abstraction, errors)
//  }
}

fileprivate extension CSVReader.Error {
  /// Error raised when the delimiter options are empty.
  /// TODO
  static func _emptyDelimiterOptions() -> CSVError<CSVReader> {
    CSVError(.invalidConfiguration,
             reason: "The delimiter options were empty.",
             help: "")
    }
}
