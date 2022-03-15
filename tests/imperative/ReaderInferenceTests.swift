@testable import CodableCSV
import XCTest

final class ReaderInferenceTests: XCTestCase {
  private enum _TestData {
    /// A CSV row representing a header row (4 fields).
    static let headers   =  ["seq", "Name", "Country", "Number Pair"]
    /// Small amount of regular CSV rows (4 fields per row).
    static let content  =  [["1", "Marcos", "Spain", "99"],
                            ["2", "Kina", "Papua New Guinea", "88"],
                            ["3", "Alex", "Germany", "77"],
                            ["4", "Marine-Anaïs", "France", "66"]]

    /// Some longer CSV rows
    static let longContent = [
      ["ff60766c-08e7-4db4-bfd3-dcc60c15251f", "foofoofoo", "barbarbar", "bazbazbaz"],
      ["f9165d00-03fc-4d8d-838c-1fba1d26d92d", "foofoofoo", "barbarbar", "bazbazbaz"],
    ]

    /// Encodes the test data into a Swift `String`.
    /// - parameter sample:
    /// - parameter delimiters: Unicode scalars to use to mark fields and rows.
    /// - returns: Swift String representing the CSV file.
    static func toCSV(_ sample: [[String]], delimiters: CSVReader.Configuration.Delimiters) -> String {
      let (f, r) = (delimiters.field.description, delimiters.row.description)
      return sample.map { $0.joined(separator: f) }.joined(separator: r).appending(r)
    }
  }
}

extension ReaderInferenceTests {
  func testInference() throws {
    let fieldDelimiters: [CSVReader.Configuration.FieldDelimiter] = [",", ";", "|", "\t"]

    var configuration = CSVReader.Configuration()
    configuration.delimiters = (field: "", row: "\n")

    for fieldDelimiter in fieldDelimiters {
      let testString = _TestData.toCSV(_TestData.content, delimiters: (fieldDelimiter, "\n"))
      let result = try CSVReader.decode(input: testString, configuration: configuration)
      XCTAssertEqual(result.rows, _TestData.content, "Delimiter: \(fieldDelimiter)")
    }
  }

  func testInference_longRows() throws {
    let fieldDelimiters: [CSVReader.Configuration.FieldDelimiter] = [",", ";", "|", "\t"]

    var configuration = CSVReader.Configuration()
    configuration.delimiters = (field: nil, row: "\n")

    for fieldDelimiter in fieldDelimiters {
      let testString = _TestData.toCSV(_TestData.longContent, delimiters: (fieldDelimiter, "\n"))
      let result = try CSVReader.decode(input: testString, configuration: configuration)
      XCTAssertEqual(result.rows, _TestData.longContent)
    }
  }

  func test_Delimiter() {
    XCTAssertEqual(Delimiter(scalars: ["~", "~"]).scalars, ["~", "~"])
    XCTAssertEqual(Delimiter(unicodeScalarLiteral: ",").scalars, [","])
    XCTAssertEqual(Delimiter(stringLiteral: "~~").scalars, ["~", "~"])
    XCTAssertEqual(Delimiter(Substring("~~"))?.scalars, ["~", "~"])
    XCTAssertEqual(Delimiter(Substring("")), nil)
  }

  func testPairs() {
    let pairs: [(String, String)] = [
      ("**-", "**~"),
    ]

    for (field, row) in pairs {
      print(field.hasPrefix(row))
      print(row.hasPrefix(field))
    }
  }

  func testExample() throws {
    let field: [Unicode.Scalar] = ["-", "-"]
    let row: Set<[Unicode.Scalar]> = [["-"]]

//    guard row.allSatisfy({ $0 != field }) else { fatalError() }

//    let s = "foo-*bar-*baz\nabc-*def-*xyz"
//    let s = "foo-**bar*-*baz\nabc-*def-*xyz"
    let s = "foo-*\"-*-*-*bar\"-*baz\nabc-*dev-*xyz"
    let reader = try CSVReader(input: s) {
      $0.delimiters = (field: "-*", row: "\n")
//      $0.escapingStrategy = .scalar("*")
    }

    for row in reader {
      print(row)
    }
  }

  func testNewApi() {
    var c = CSVReader.Configuration()

    // Invalid
//    c.delimiters = (field: "", row: "")
//    c.delimiters = (field: .infer(options: []), row: "\n")
    c.delimiters = (field: .infer, row: .init("\n", "")!)


//    c.delimiters = (field: .infer(options: [",", "--"]), row: .init("", "")!)

    // Writer
    //
    // - Configuration
    //   - Delimiters
    // - Settings
    //   - Delimiters
    //   OR
    // - Configuration
    //   - Delimiter
    //     - Pair
    // - Settings
    //   - Delimiter
    //     - Pair

    // Configuration: (field: Delimiter, row: Delimiter) aka CSVWriter.Configuration.Delimiters
    // a) Settings: (field: [Unicode.Scalar], row: [Unicode.Scalar])
    // b) Settings: (field: Delimiter, row: Delimiter)

    // Reader
    // - Configuration
    //   - Delimiters
    //   - FieldDelimiter
    //   - RowDelimiter
    // - Settings
    //   - Delimiters
    // OR
    // - Configuration
    //   - Delimiter
    //     - Pair
    //     - Field
    //     - Row
    // - Settings
    //   - Delimiter
    //     - Pair


    // Configuration: (field: CSVReader.Configuration.Delimiter.Field, row: CSVReader.Configuration.Delimiter.Row) aka CSVReader.Configuration.Delimiters
    // Settings: (field: Delimiter, row: Set<Delimiter>) aka CSVReader.Settings.Delimiters
  }
}

// options, choices, possibleValues

// | -> U+007C, Math Symbol (Sm)
// , -> U+002C, Other Punctuation (Po)
// ; -> U+003B, Other Punctuation (Po)
// : -> U+003A, Other Punctuation (Po)
// \t -> U+0009, Control (Cc)
// " " -> U+0020, Space Separator (Zs)
