//
//  ModelsView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 14/10/2026.
//

import SwiftUI

struct ModelsView: View {
    @Environment(ModelStore.self) private var models
    @State private var isImporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(models.all) { model in
                    row(model)
                }

                Button {
                    isImporting = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 40)
                        Text("Add a Model")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                    .card()
                }
                .buttonStyle(.plain)

                if let errorMessage = models.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Models run on your device and work offline once downloaded. Bigger is smarter but slower. Hold a model to delete it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .sheet(isPresented: $isImporting) {
            ImportModelView()
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: models.selectedID)
        .task {
            await models.refresh()
        }
    }

    private func tag(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
    }

    private func row(_ model: AIModel) -> some View {
        let isInstalled = models.downloaded.contains(model.id)

        return HStack(spacing: 14) {
            ModelIcon(model: model, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    model.styledName
                        .font(.headline)
                    if model == AIModel.recommended {
                        RecommendedBadge()
                    }
                }
                Text(model.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FlowLayout(spacing: 6) {
                    tag(model.size ?? String(localized: "Built in"), systemImage: model.isBuiltIn ? "iphone" : "arrow.down.circle")
                    tag(model.supportsVision ? String(localized: "Sees images") : String(localized: "Text only"), systemImage: model.supportsVision ? "eye" : "text.alignleft")
                }
                .padding(.top, 4)
                if !model.fitsDevice {
                    Text("Needs a newer device")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            accessory(model, isInstalled: isInstalled)
        }
        .padding(16)
        .contentShape(Rectangle())
        .card()
        .onTapGesture {
            if isInstalled && model.fitsDevice {
                models.select(model)
            }
        }
        .contextMenu {
            if (isInstalled && !model.isBuiltIn) || model.isCustom {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    models.delete(model)
                }
            }
        }
    }

    @ViewBuilder
    private func accessory(_ model: AIModel, isInstalled: Bool) -> some View {
        if models.selectedID == model.id {
            Image(systemName: "checkmark")
                .font(.headline)
        } else if isInstalled {
            EmptyView()
        } else if models.downloading.contains(model.id) {
            Button {
                models.cancel(model)
            } label: {
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.02, models.progress(of: model)))
                        .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: models.progress(of: model))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                models.download(model)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(uiColor: .tertiarySystemBackground), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!model.fitsDevice)
        }
    }
}

struct ImportModelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ModelStore.self) private var models
    @State private var input = ""
    @State private var result: CustomModel?
    @State private var errorMessage: String?
    @State private var isChecking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $input, prompt: Text(verbatim: "mlx-community/…")) {
                        Text("Hugging Face model")
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.search)
                    .onSubmit(check)
                    .onChange(of: input) {
                        result = nil
                        errorMessage = nil
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("Paste a model ID or link from Hugging Face. MLX models from mlx-community work best.")
                    }
                }

                if let result {
                    let model = result.model
                    Section {
                        HStack(spacing: 14) {
                            ModelIcon(model: model, size: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: model.name)
                                    .font(.headline)
                                Text(verbatim: model.size ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !model.fitsDevice {
                                    Text("Needs a newer device")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add a Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isChecking {
                        ProgressView()
                    } else if let result {
                        Button("Download", systemImage: "arrow.down") {
                            models.add(result)
                            dismiss()
                        }
                        .disabled(!result.model.fitsDevice)
                    } else {
                        Button("Check", systemImage: "magnifyingglass", action: check)
                            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func check() {
        isChecking = true
        errorMessage = nil
        Task {
            do {
                result = try await CustomModel.inspect(input)
            } catch {
                errorMessage = error.localizedDescription
            }
            isChecking = false
        }
    }
}

