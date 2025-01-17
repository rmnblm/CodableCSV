extension CSVWriter {
  /// Configuration for how to write CSV data.
  public struct Configuration {
    /// The encoding used to serialize the CSV information.
    ///
    /// If no encoding is provided, UTF8 is presumed unless the CSV writer points to a file, in which case that file encoding will be used.
    public var encoding: String.Encoding?
    /// Indicates whether a [Byte Order Mark](https://en.wikipedia.org/wiki/Byte_order_mark) will be included at the beginning of the CSV representation.
    ///
    /// The BOM indicates the string encoding used for the CSV representation. If any, they always are the first bytes on a file.
    public var bomStrategy: Strategy.BOM
    /// The field and row delimiters.
    public var delimiters: Delimiters
    /// The strategy to allow/disable escaped fields and how.
    public var escapingStrategy: Strategy.Escaping
    /// The row of headers to write at the beginning of the CSV data.
    ///
    /// If empty, no row will be written.
    public var headers: [String]

    /// Designated initializer setting the default values.
    public init() {
      self.encoding = nil
      self.bomStrategy = .convention
      self.delimiters = (field: ",", row: "\n")
      self.escapingStrategy = .doubleQuote
      self.headers = Array()
    }

    /// The CSV pair of delimiters (field & row delimiters).
    /// - todo: Ensure field and row are mutually exclusive as part of type.
    public typealias Delimiters = (field: Delimiter, row: Delimiter)
  }
}

extension Strategy {
  /// Indicates whether the [Byte Order Mark](https://en.wikipedia.org/wiki/Byte_order_mark) will be serialize with the date or not.
  public enum BOM {
    /// Includes the optional BOM at the beginning of the CSV representation for a small number of encodings.
    ///
    /// A BOM will only be included for the following cases:
    /// - `.utf16` and `.unicode`, in which case the BOM for UTF 16 big endian encoding will be used.
    /// - `.utf32` in which ase the BOM for UTF 32 big endian encoding will be used.
    /// - For any other case, no BOM will be written.
    case convention
    /// Always writes a BOM when possible (i.e. for Unicode encodings).
    case always
    /// Never writes a BOM.
    case never
  }
}
