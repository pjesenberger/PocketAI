//
//  DownloadToast.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 24/10/2026.
//

import SwiftUI

struct DownloadToast: View {
    @Environment(ModelStore.self) private var models
    @Environment(\.scenePhase) private var scenePhase
    @State private var completed: AIModel?

    private var downloading: AIModel? {
        models.all.first { models.downloading.contains($0.id) }
    }

    private var visibleCompleted: AIModel? {
        downloading == nil ? completed : nil
    }

    var body: some View {
        ZStack {
            if let model = downloading {
                progressToast(model)
                    .transition(toastTransition)
            } else if let model = visibleCompleted {
                completedToast(model)
                    .transition(toastTransition)
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: downloading?.id)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: completed?.id)
        .onChange(of: models.completedCount) {
            completed = models.completed
        }
        .task(id: "\(visibleCompleted?.id ?? "")-\(scenePhase)") {
            guard visibleCompleted != nil, scenePhase == .active else { return }
            try? await Task.sleep(for: .seconds(3))
            completed = nil
        }
        .sensoryFeedback(.success, trigger: models.completedCount)
    }

    private var toastTransition: AnyTransition {
        .move(edge: .top).combined(with: .opacity)
    }

    private func progressToast(_ model: AIModel) -> some View {
        let progress = models.progress(of: model)

        return HStack(spacing: 12) {
            ModelIcon(model: model, size: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    model.styledName
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(.primary)
                    .animation(.linear(duration: 0.2), value: progress)
            }

            Button {
                models.cancel(model)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.1), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
    }

    private func completedToast(_ model: AIModel) -> some View {
        HStack(spacing: 12) {
            ModelIcon(model: model, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                model.styledName
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("Downloaded, ready to use")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
    }
}
