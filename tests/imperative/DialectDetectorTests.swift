@testable import CodableCSV
import XCTest

final class DialectDetectorTests: XCTestCase {}

// MARK: - Tests for detectDialect

extension DialectDetectorTests {
  func test_makeDialectCandidates() throws {
    let dialects = try DelimiterInferrer.makeDialectCandidates([",", ";"], ["\n", "\r", "\r\n"])
    XCTAssertEqual(
      dialects,
      [
        try .init(field: ",", row: ["\n"]),
        try .init(field: ",", row: ["\r"]),
        try .init(field: ";", row: ["\n"]),
        try .init(field: ",", row: ["\r\n"]),
        try .init(field: ";", row: ["\r"]),
        try .init(field: ";", row: ["\r\n"]),
      ]
    )
  }
}

extension DialectDetectorTests {
  func test_detectDialect() throws {
    // Adapted from CPython
    // See: https://github.com/python/cpython/blob/f4c03484da59049eb62a9bf7777b963e2267d187/Lib/test/test_csv.py#L1039
    let dialects = [
      (
        """
        Harry's, Arlington Heights, IL, 2/1/03, Kimi Hayes
        Shark City, Glendale Heights, IL, 12/28/02, Prezence
        Tommy's Place, Blue Island, IL, 12/28/02, Blue Sunday/White Crow
        Stonecutters Seafood and Chop House, Lemont, IL, 12/19/02, Week Back
        """,
        try DelimiterInferrer.Dialect(field: ",", row: "\n")
      ),
//      (
//        """
//        'Harry''s':'Arlington Heights':'IL':'2/1/03':'Kimi Hayes'
//        'Shark City':'Glendale Heights':'IL':'12/28/02':'Prezence'
//        'Tommy''s Place':'Blue Island':'IL':'12/28/02':'Blue Sunday/White Crow'
//        'Stonecutters ''Seafood'' and Chop House':'Lemont':'IL':'12/19/02':'Week Back'
//        """,
//        DialectDetector.Dialect(fieldDelimiter: ":")
//      ),
    ]

    let detector = try DelimiterInferrer(possibleFieldDelimiters: [",", ";", "\t"], possibleRowDelimiters: ["\n"])

    for (csv, expectedDialect) in dialects {
      let dialect = detector.detectDialect(stringScalars: Array(csv.unicodeScalars))
      XCTAssertEqual(dialect, expectedDialect, csv.debugDescription)
    }
  }
}

// MARK: - Tests for calculatePatternScore

extension DialectDetectorTests {
  // Adapted from CleverCSV
  // See: https://github.com/alan-turing-institute/CleverCSV/blob/master/tests/test_unit/test_detect_pattern.py#L160-L195
  func test_calculatePatternScore() throws {
    let dialectScores: [(DelimiterInferrer.Dialect, Double)] = [
      (try .init(field: ",", row: "\n"), 7 / 4),
      (try .init(field: ";", row: "\n"), 10 / 3),
    ]
    let csv = #"""
      7,5; Mon, Jan 12;6,40
      100; Fri, Mar 21;8,23
      8,2; Thu, Sep 17;2,71
      538,0;;7,26
      "NA"; Wed, Oct 4;6,93
      """#

    for (dialect, expectedScore) in dialectScores {
      let score = DelimiterInferrer.calculatePatternScore(stringScalars: Array(csv.unicodeScalars), dialect: dialect)
      XCTAssertEqual(score, expectedScore, "Delimiter: \(dialect.field)")
    }
  }

  /// Demonstrates that it is useful to check for the correctness of the CSV
  /// that results from a particular dialect because there may be instances where
  /// two field delimiters both get a score of 1.0 despite one of them leading to
  /// a valid CSV and the other leading to a malformed CSV
  func test_calculatePatternScore_TieBreaking() throws {
    let csv = """
      foo;,bar
      baz;,"boo"
      """

    let dialects: [(DelimiterInferrer.Dialect, Double)] = [
      (try .init(field: ",", row: "\n"), 1.0),
      (try .init(field: ";", row: "\n"), 0.5),
    ]

    for (dialect, expectedScore) in dialects {
      let msg = "Delimiter: \(dialect.field)"
      let scalars = Array(csv.unicodeScalars)
      let score = DelimiterInferrer.calculatePatternScore(stringScalars: scalars, dialect: dialect)
      XCTAssertEqual(score, expectedScore, msg)
      let abstraction = DelimiterInferrer.makeAbstraction(stringScalars: scalars, dialect: dialect)
      XCTAssertEqual(abstraction, [.cell, .fieldDelimiter, .cell, .rowDelimiter, .cell, .fieldDelimiter, .cell], msg)
    }
  }
}

// MARK: - Tests for makeAbstraction

extension DialectDetectorTests {
  func test_makeAbstraction() throws {
    let abstractions: [(String, [DelimiterInferrer.Abstraction])] = [
      ("", []),
      ("foo", [.cell]),

      (",", [.cell, .fieldDelimiter, .cell]),
      (",,", [.cell, .fieldDelimiter, .cell, .fieldDelimiter, .cell]),

//      ("\n", [.cell, .rowDelimiter]),
//      ("\n\n", [.cell, .rowDelimiter, .cell, .rowDelimiter]),

      (",\n,", [.cell, .fieldDelimiter, .cell, .rowDelimiter, .cell, .fieldDelimiter, .cell]),
      (",foo\n,bar", [.cell, .fieldDelimiter, .cell, .rowDelimiter, .cell, .fieldDelimiter, .cell]),
    ]
    let dialect = try DelimiterInferrer.Dialect(field: ",", row: "\n")

    for (csv, expected) in abstractions {
      let abstraction = DelimiterInferrer.makeAbstraction(stringScalars: Array(csv.unicodeScalars), dialect: dialect)
      XCTAssertEqual(abstraction, expected, csv.debugDescription)
    }
  }

  func test_makeAbstraction_HandlesEscaping() throws {
    let escapingAbstractions: [(String, [DelimiterInferrer.Abstraction])] = [
      (#"  "foo",bar                     "#, [.cell, .fieldDelimiter, .cell]),
      (#"  "foo ""quoted"" \n ,bar",baz  "#, [.cell, .fieldDelimiter, .cell]),
      (#"  a,"bc""d""e""f""a",\n         "#, [.cell, .fieldDelimiter, .cell, .fieldDelimiter, .cell]),
    ]
    let dialect = try DelimiterInferrer.Dialect(field: ",", row: "\n")
    for (csv, expected) in escapingAbstractions {
      let strippedCSV = csv.trimmingCharacters(in: .whitespaces)
      let abstraction = DelimiterInferrer.makeAbstraction(stringScalars: Array(strippedCSV.unicodeScalars), dialect: dialect)
      XCTAssertEqual(abstraction, expected, csv.debugDescription)
    }
  }

  func test_makeAbstraction_HandlesInvalidEscaping() throws {
    let dialect = try DelimiterInferrer.Dialect(field: ",", row: "\n")
    let malformedCSVs: [(String, [DelimiterInferrer.Abstraction])] = [
      // escaping
      (#"  foo,x"bar"  "#, [.cell, .fieldDelimiter, .cell]),
      (#"  foo,"bar"x  "#, [.cell, .fieldDelimiter, .cell]),
      (#"  foo,"bar    "#, [.cell, .fieldDelimiter, .cell]),
      // different number of fields per row
      ("foo,bar\n\n", [.cell, .fieldDelimiter, .cell, .rowDelimiter, .cell, .rowDelimiter]),
    ]

    for (csv, expected) in malformedCSVs {
      let strippedCSV = csv.trimmingCharacters(in: .whitespaces)
      let abstraction = DelimiterInferrer.makeAbstraction(stringScalars: Array(strippedCSV.unicodeScalars), dialect: dialect)
      XCTAssertEqual(abstraction, expected, strippedCSV.debugDescription)
    }
  }
}
