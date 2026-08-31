import Combine
import Foundation
import Sparkle
import SwiftUI

public struct WisentUpdateConfiguration: Equatable, Sendable {
    public static let skipArgument = "--skip-updates"

    public let feedURL: URL?
    public let publicKey: String?
    public let updatesDisabled: Bool

    public var isConfigured: Bool {
        feedURL != nil && publicKey?.isEmpty == false && !updatesDisabled
    }

    public init(
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:],
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let feed = (infoDictionary["SUFeedURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (infoDictionary["SUPublicEDKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        feedURL = feed.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        publicKey = key.flatMap { $0.isEmpty ? nil : $0 }
        updatesDisabled = arguments.contains(Self.skipArgument)
    }
}

/// The update mechanism, and the operator's choice about how it behaves.
///
/// Two decisions, and they are different questions. Whether the app looks for
/// an update on its own schedule is one; whether an update it found installs
/// itself, or waits to be asked, is the other. Sparkle keeps both, so this type
/// keeps neither: reading and writing them goes straight through `SPUUpdater`,
/// which persists them in the app's own defaults. A second copy here would be a
/// preference that disagrees with the updater obeying it.
///
/// The `Info.plist` keys — `SUEnableAutomaticChecks`, `SUAutomaticallyUpdate`,
/// `SUAllowsAutomaticUpdates`, `SUScheduledCheckInterval` — are first-launch
/// defaults for exactly these values, and nothing more. Before this existed the
/// pack shipped `SUEnableAutomaticChecks` and `SUAutomaticallyUpdate` both true
/// in eleven applications and offered no way to see or change either, so every
/// app silently installed whatever its feed served and the operator was never
/// asked.
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

    /// Whether the app looks for updates on its own, without being asked.
    public var checksAutomatically: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set {
            guard let updater = controller?.updater else { return }
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    /// Whether an update the app found installs itself.
    ///
    /// Separate from the question above because the answers differ: an operator
    /// who wants to know an update exists does not necessarily want it applied
    /// under them while they are working.
    public var installsAutomatically: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set {
            guard let updater = controller?.updater else { return }
            objectWillChange.send()
            updater.automaticallyDownloadsUpdates = newValue
        }
    }
}

/// The update items every Wisent desktop app puts in its own menu: the verb, and
/// the two choices behind it.
///
/// It lives in one place because the alternative was seventeen Settings screens
/// that do not exist. The menu is a surface every app already has, and a
/// checkmark beside a menu item is how macOS has always stated a preference of
/// this shape.
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

        Toggle(
            "Check for Updates Automatically",
            isOn: Binding(
                get: { updater.checksAutomatically },
                set: { updater.checksAutomatically = $0 }
            )
        )
        .disabled(!updater.configuration.isConfigured)

        // Off is the honest default and it is stated, not implied: an update
        // that installs itself while the operator is mid-session is a decision
        // they should have made on purpose. The item stays visible when
        // automatic checking is off, so the pair reads as one setting with two
        // steps rather than an item that vanishes.
        Toggle(
            "Install Updates Automatically",
            isOn: Binding(
                get: { updater.installsAutomatically },
                set: { updater.installsAutomatically = $0 }
            )
        )
        .disabled(!updater.configuration.isConfigured || !updater.checksAutomatically)
    }
}
