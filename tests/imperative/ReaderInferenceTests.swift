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

  func testTryOutNewAPI() throws {
    var c = CSVReader.Configuration()
    // current usage
    c.delimiters = (field: "", row: "\n")
    c.delimiters = (field: nil, row: nil)
    c.delimiters = (field: "hello", row: .standard)

    // TODO: This should not be possible
    var writerConfiguration = CSVWriter.Configuration()
//    writerConfiguration.delimiters = (field: .infer, row: "\n")

    // valid
    writerConfiguration.delimiters = (field: ",", row: "\n")

    // options, choices, possibleValues

    // | -> U+007C, Math Symbol (Sm)
    // , -> U+002C, Other Punctuation (Po)
    // ; -> U+003B, Other Punctuation (Po)
    // : -> U+003A, Other Punctuation (Po)
    // \t -> U+0009, Control (Cc)
    // " " -> U+0020, Space Separator (Zs)

    c.delimiters = (field: .infer(options: [",", ";"]), row: "\n")
    c.delimiters = (field: .infer(options: ["--", ";"]), row: "\n")
    c.delimiters = (field: .infer, row: "\n")
    c.delimiters = (field: .infer, row: .init("\n", "\r\n")!)
    c.delimiters = (field: .infer(options: ["Some long string"]), row: "\n")

    // Invalid
    c.delimiters = (field: "", row: "")
    c.delimiters = (field: .infer(options: []), row: "\n")
    c.delimiters = (field: .infer, row: .init("\n", "")!)
    c.delimiters = (field: "--", row: "--")
    c.delimiters = (field: .infer(options: [",", "--"]), row: "--")
    c.delimiters = (field: .infer(options: [",", "--"]), row: .infer(options: ["\n", "--"]))
    c.delimiters = (field: .infer(options: [",", "--"]), row: .init("", "")!)


//    let x: InferrableDelimiter = .

    // Writer
    // - Configuration
    //   - Delimiters

    // Delimiter
    // - Pair

    // Configuration: (field: StaticDelimiter, row: StaticDelimiter) aka CSVWriter.Configuration.Delimiters
    // a) Settings: (field: [Unicode.Scalar], row: [Unicode.Scalar])
    // b) Settings: (field: StaticDelimiter, row: StaticDelimiter)


    // Reader
    // - Configuration
    //   - Delimiters
    // - Settings
    //   - Delimiters

    // - Delimiter
    //   - Field
    //   - Row

    // Configuration: (field: CSVReader.Configuration.Delimiter.Field, row: CSVReader.Configuration.Delimiter.Row) aka CSVReader.Configuration.Delimiters
    // Settings: (field: StaticDelimiter, row: Set<StaticDelimiter>) aka CSVReader.Settings.Delimiters
  }
}
