//
//  UpdateChecker.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 14/10/2026.
//

import SwiftUI

@Observable
final class UpdateChecker {
    var latestVersion: String?
    var storeURL: URL?
    var isSheetPresented = false

    var isAvailable: Bool {
        guard let latestVersion else { return false }
        return latestVersion.compare(Self.currentVersion, options: .numeric) == .orderedDescending
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func check() async {
        guard let bundleID = Bundle.main.bundleIdentifier, let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)") else { return }
        struct Response: Decodable {
            struct Result: Decodable {
                let version: String
                let trackViewUrl: String
            }
            let results: [Result]
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url), let result = try? JSONDecoder().decode(Response.self, from: data).results.first else { return }
        latestVersion = result.version
        storeURL = URL(string: result.trackViewUrl)
        let key = "seenUpdate"
        if isAvailable, UserDefaults.standard.string(forKey: key) != result.version {
            UserDefaults.standard.set(result.version, forKey: key)
            isSheetPresented = true
        }
    }
}

struct UpdateSheet: View {
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("New Update")
                    .font(.title2.weight(.bold))
                if let version = updates.latestVersion {
                    Text("Version \(version) is available.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 28)

            VStack(spacing: 4) {
                Button("Update") {
                    if let url = updates.storeURL {
                        openURL(url)
                    }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Not Now") {
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 32)
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
    }
}
