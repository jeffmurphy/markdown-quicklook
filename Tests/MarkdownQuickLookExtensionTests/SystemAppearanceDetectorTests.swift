//
//  SystemAppearanceDetectorTests.swift
//  MarkdownQuickLookExtensionTests
//

import XCTest
import Cocoa

final class SystemAppearanceDetectorTests: XCTestCase {

    func test_darkAqua_mapsToDarkTheme() {
        let appearance = NSAppearance(named: .darkAqua)!
        XCTAssertEqual(SystemAppearanceDetector.theme(for: appearance), .dark)
    }

    func test_aqua_mapsToLightTheme() {
        let appearance = NSAppearance(named: .aqua)!
        XCTAssertEqual(SystemAppearanceDetector.theme(for: appearance), .light)
    }
}
