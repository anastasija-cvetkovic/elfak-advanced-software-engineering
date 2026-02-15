// NetworkBannerView.swift
// Trusty Bookshelf — Offline-First SwiftUI Tutorial
//
// A banner that slides in from the top of the screen when the device is offline.
// Red        = real network loss (device has no connectivity)
// Light gray = simulated offline mode (user tapped the demo toggle)

import SwiftUI

struct NetworkBannerView: View {
    let networkMonitor: NetworkMonitor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .imageScale(.small)
            Text(networkMonitor.simulateOffline
                 ? "Offline Mode (Simulated)"
                 : "No Internet Connection")
                .font(.caption.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray4))
    }
}

#Preview("Offline — real") {
    let monitor = NetworkMonitor()
    return NetworkBannerView(networkMonitor: monitor)
}
