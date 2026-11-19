import Foundation

// Reversible encoding only obscures selected literals in the compiled library.
// It does not conceal the policy or protect secrets from a determined analyst.
internal enum RSKStrings {
    private static func d(_ bytes: [UInt8]) -> String {
        String(decoding: bytes.map { $0 ^ 0x5a }, as: UTF8.self)
    }
    static var a: String { d([15, 9]) }
    static var b: String { d([63, 52]) }
    static var c: [String] {
        [[47, 46, 47, 52], [51, 42, 41, 63, 57], [42, 42, 42],
         [46, 59, 42], [46, 47, 52]].map(d)
    }
}
