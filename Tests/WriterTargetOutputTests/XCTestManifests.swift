#if !canImport(ObjectiveC)
import XCTest

extension RewriterOutputTargetTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__RewriterOutputTargetTests = [
        ("testIndented", testIndented),
        ("testOutput", testOutput),
        ("testOutputInline", testOutputInline),
        ("testOutputInlineWithSpace", testOutputInlineWithSpace),
    ]
}

extension StringRewriterOutputTests {
    // DO NOT MODIFY: This is autogenerated, use:
    //   `swift test --generate-linuxmain`
    // to regenerate.
    static let __allTests__StringRewriterOutputTests = [
        ("testDecreaseIndentation", testDecreaseIndentation),
        ("testDecreaseIndentationStopsAtZero", testDecreaseIndentationStopsAtZero),
        ("testIncreaseIndentation", testIncreaseIndentation),
        ("testOnAfterOutputTrimsWhitespaces", testOnAfterOutputTrimsWhitespaces),
        ("testOutputInline", testOutputInline),
        ("testOutputLine", testOutputLine),
        ("testOutputLineIndented", testOutputLineIndented),
        ("testOutputRaw", testOutputRaw),
    ]
}

public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RewriterOutputTargetTests.__allTests__RewriterOutputTargetTests),
        testCase(StringRewriterOutputTests.__allTests__StringRewriterOutputTests),
    ]
}
#endif
