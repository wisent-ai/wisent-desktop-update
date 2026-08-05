import Foundation
import XCTest
@testable import WisentDesktopUpdate

final class WisentUpdateConfigurationTests: XCTestCase {
    func testCompleteConfigurationEnablesUpdater() {
        let configuration = WisentUpdateConfiguration(
            infoDictionary: [
                "SUFeedURL": "https://github.com/wisent-ai/example-desktop/releases/latest/download/appcast.xml",
                "SUPublicEDKey": "public-key",
                "SUEnableAutomaticChecks": true,
            ],
            arguments: ["Example"]
        )

        XCTAssertEqual(
            configuration.feedURL,
            URL(string: "https://github.com/wisent-ai/example-desktop/releases/latest/download/appcast.xml")
        )
        XCTAssertEqual(configuration.publicKey, "public-key")
        XCTAssertTrue(configuration.automaticChecksEnabled)
        XCTAssertTrue(configuration.isConfigured)
    }

    func testIncompleteConfigurationKeepsUpdaterDisabled() {
        let incompleteConfigurations: [[String: Any]] = [
            ["SUFeedURL": "", "SUPublicEDKey": "public-key"],
            ["SUFeedURL": "https://example.invalid/appcast.xml", "SUPublicEDKey": ""],
            ["SUPublicEDKey": "public-key"],
        ]

        for infoDictionary in incompleteConfigurations {
            let configuration = WisentUpdateConfiguration(
                infoDictionary: infoDictionary,
                arguments: ["Example"]
            )
            XCTAssertFalse(configuration.isConfigured)
        }
    }

    func testSkipArgumentDisablesConfiguredUpdater() {
        let configuration = WisentUpdateConfiguration(
            infoDictionary: [
                "SUFeedURL": "https://example.invalid/appcast.xml",
                "SUPublicEDKey": "public-key",
            ],
            arguments: ["Example", WisentUpdateConfiguration.skipArgument]
        )

        XCTAssertTrue(configuration.updatesDisabled)
        XCTAssertFalse(configuration.isConfigured)
    }
}
