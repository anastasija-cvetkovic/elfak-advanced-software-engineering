// NetworkMonitor.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// Wraps NWPathMonitor (Network.framework) in an @Observable class.
// Any SwiftUI view that reads effectivelyOnline or simulateOffline
// will automatically re-render when those values change.
//
// KEY EDUCATIONAL FEATURE — simulateOffline:
//   Toggling this property immediately makes the entire app behave as if offline
//   without putting the device in airplane mode. This is crucial for live demos
//   because airplane mode would also disconnect Xcode's wireless debugging session.

import Network
import Observation

@Observable
final class NetworkMonitor {

    // MARK: - Public State

    /// True when the device has an active network path (WiFi, Cellular, etc.)
    private(set) var isConnected: Bool = true

    /// Human-readable connection type for the UI.
    private(set) var connectionType: String = "Unknown"

    /// When true, the app acts as if there is no network, regardless of real connectivity.
    /// Used exclusively for demo/educational purposes.
    var simulateOffline: Bool = false

    /// The value the rest of the app should use when deciding whether to make network calls.
    /// Combines real connectivity with the simulate toggle.
    var effectivelyOnline: Bool {
        isConnected && !simulateOffline
    }

    // MARK: - Private NWPathMonitor

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.elfak.bookshelf.NetworkMonitor",
                                      qos: .utility)

    // MARK: - Lifecycle

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // NWPathMonitor delivers on its own queue; dispatch to main for @Observable
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = {
                    if path.usesInterfaceType(.wifi)     { return "WiFi" }
                    if path.usesInterfaceType(.cellular) { return "Cellular" }
                    if path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
                    return "Other"
                }()
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
