//
//  RelativeResourceResolverTests.swift
//  MarkdownQuickLookExtensionTests
//

import XCTest

final class RelativeResourceResolverTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writeFile(_ name: String, contents: Data) -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! contents.write(to: url)
        return url
    }

    // MARK: - Images: existing file

    func test_existingRelativeImage_isRewrittenToBase64DataURI() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // arbitrary bytes, not a real PNG - fine for this test
        _ = writeFile("images/pic.png", contents: imageData)

        let markdown = "Here is an image: ![alt text](images/pic.png)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)

        let expectedBase64 = imageData.base64EncodedString()
        XCTAssertTrue(result.contains("![alt text](data:image/png;base64,\(expectedBase64))"))
        XCTAssertFalse(result.contains("images/pic.png"))
    }

    func test_existingImage_preservesOptionalTitleAttribute() {
        let imageData = Data([0x01, 0x02, 0x03])
        _ = writeFile("pic.jpg", contents: imageData)

        let markdown = #"![alt](pic.jpg "My Title")"#
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)

        XCTAssertTrue(result.contains("\"My Title\")"))
        XCTAssertTrue(result.contains("data:image/jpeg;base64,"))
    }

    // MARK: - Images: missing file (graceful degradation)

    func test_missingRelativeImage_isLeftUntouched() {
        let markdown = "![alt](does-not-exist.png)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)

        XCTAssertEqual(result, markdown, "missing image reference must be left exactly as-is so the browser's native broken-image handling takes over")
    }

    // MARK: - Images: non-relative references left untouched

    func test_absoluteHTTPImageURL_isLeftUntouched() {
        let markdown = "![alt](https://example.com/pic.png)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)
        XCTAssertEqual(result, markdown)
    }

    func test_alreadyDataURIImage_isLeftUntouched() {
        let markdown = "![alt](data:image/png;base64,AAAA)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)
        XCTAssertEqual(result, markdown)
    }

    func test_absolutePathImage_isLeftUntouched() {
        let markdown = "![alt](/etc/hosts)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)
        XCTAssertEqual(result, markdown)
    }

    // MARK: - Links

    func test_relativeLink_isRewrittenToAbsoluteFileURL() {
        let markdown = "See [the doc](notes/other.md) for details."
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)

        let expected = tempDir.appendingPathComponent("notes/other.md").standardizedFileURL.absoluteString
        XCTAssertTrue(result.contains("[the doc](\(expected))"), "got: \(result)")
    }

    func test_anchorOnlyLink_isLeftUntouched() {
        let markdown = "[jump to section](#some-section)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)
        XCTAssertEqual(result, markdown)
    }

    func test_absoluteHTTPLink_isLeftUntouched() {
        let markdown = "[external](https://example.com)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)
        XCTAssertEqual(result, markdown)
    }

    // MARK: - Images and links don't interfere with each other

    func test_imageSyntaxIsNotAlsoTreatedAsALink() {
        let imageData = Data([0xAA])
        _ = writeFile("pic.png", contents: imageData)

        let markdown = "![alt](pic.png)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)

        // Should be base64-embedded exactly once, not also rewritten by
        // the link resolver as if it were a plain [text](url) link.
        XCTAssertTrue(result.hasPrefix("![alt](data:image/png;base64,"))
        XCTAssertEqual(result.components(separatedBy: "data:image/png").count, 2, "should only be transformed once")
    }

    func test_mixedImageAndLinkInSameDocument_bothResolveIndependently() {
        let imageData = Data([0x01])
        _ = writeFile("pic.png", contents: imageData)

        let markdown = "![alt](pic.png) and [a link](other.md)"
        let result = RelativeResourceResolver.resolve(markdownSource: markdown, documentDirectory: tempDir)

        XCTAssertTrue(result.contains("data:image/png;base64,AQ=="))
        let expectedLink = tempDir.appendingPathComponent("other.md").standardizedFileURL.absoluteString
        XCTAssertTrue(result.contains("[a link](\(expectedLink))"))
    }
}
