import Combine
import Foundation
import Sparkle
import SwiftUI

public struct WisentUpdateConfiguration: Equatable, Sendable {
    public static let skipArgument = "--skip-updates"

    public let feedURL: URL?
    public let publicKey: String?
    public let automaticChecksEnabled: Bool
    public let updatesDisabled: Bool

    public var isConfigured: Bool {
        feedURL != nil && publicKey?.isEmpty == false && !updatesDisabled
    }

    public init(
        infoDictionary: [String: Any],
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let feed = (infoDictionary["SUFeedURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (infoDictionary["SUPublicEDKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        feedURL = feed.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        publicKey = key.flatMap { $0.isEmpty ? nil : $0 }
        automaticChecksEnabled = infoDictionary["SUEnableAutomaticChecks"] as? Bool ?? true
        updatesDisabled = arguments.contains(Self.skipArgument)
    }
}

@MainActor
public final class WisentUpdater: ObservableObject {
    @Published public private(set) var canCheckForUpdates = false

    public let configuration: WisentUpdateConfiguration

    private let controller: SPUStandardUpdaterController?
    private var canCheckObservation: AnyCancellable?

    public init(
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:],
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let configuration = WisentUpdateConfiguration(
            infoDictionary: infoDictionary,
            arguments: arguments
        )
        self.configuration = configuration

        guard configuration.isConfigured else {
            controller = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
        canCheckObservation = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
    }

    public func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller?.checkForUpdates(nil)
    }
}

public struct WisentCheckForUpdatesCommand: View {
    @ObservedObject private var updater: WisentUpdater
    private let title: String

    public init(
        updater: WisentUpdater,
        title: String = "Check for Updates…"
    ) {
        self.updater = updater
        self.title = title
    }

    public var body: some View {
        Button(title) {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
