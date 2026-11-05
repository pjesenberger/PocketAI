//
//  ChatInputView.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 11/10/2026.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

struct ChatInputView: View {
    @Binding var text: String
    let shortcuts: [Shortcut]
    @Binding var selectedShortcuts: Set<UUID>
    @Binding var images: [Data]
    @Binding var files: [FileAttachment]
    let supportsImages: Bool
    var isFocused: FocusState<Bool>.Binding
    @Binding var attachment: AttachmentMode?
    let errorMessage: String?
    let isResponding: Bool
    let isEditing: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    let onCancelEdit: () -> Void
    @State private var openedMode: AttachmentMode?
    @AppStorage("theme") private var theme = AppTheme.white
    @State private var isExpanded = false
    @State private var isContentVisible = false
    @State private var choiceFrames: [AttachmentMode: CGRect] = [:]
    @State private var rowFrame: CGRect = .zero
    @State private var barHeight: CGFloat = 44
    @State private var rowBottom: CGFloat = 0
    @State private var isImporting = false
    private let maxImages = 4
    private let maxFiles = 3
    private static let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    private let space = "chatInput"
    private let rowGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                if isEditing {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil")
                        Text("Editing message")
                        Spacer()
                        Button(action: onCancelEdit) {
                            Image(systemName: "xmark")
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
                    .padding(.trailing, 6)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08), in: .rect(cornerRadius: 16, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if !images.isEmpty || !files.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(files.enumerated()), id: \.offset) { index, file in
                                FileChip(file: file) {
                                    if files.indices.contains(index) {
                                        files.remove(at: index)
                                    }
                                }
                            }
                            ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                                AttachmentThumbnail(data: data)
                                    .overlay(alignment: .topTrailing) {
                                        RemoveButton {
                                            if images.indices.contains(index) {
                                                images.remove(at: index)
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .excludedFromSideMenu("attachments")
                    .padding(.top, 6)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    Button {
                        attachment = attachment == nil ? .choosing : nil
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .rotationEffect(.degrees(attachment == nil ? 0 : 45))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(isResponding)
                    .sensoryFeedback(.impact(weight: .light), trigger: attachment == nil)

                    TextField("Ask PocketAI", text: $text, axis: .vertical)
                        .lineLimit(1...6)
                        .frame(minHeight: 32)
                        .focused(isFocused)
                        .simultaneousGesture(TapGesture().onEnded { attachment = nil })
                        .onChange(of: text) {
                            if attachment != nil {
                                attachment = nil
                            }
                        }

                    Button {
                        if isResponding {
                            onStop()
                        } else {
                            closeAttachmentsInstantly()
                            onSend()
                        }
                    } label: {
                        Image(systemName: isResponding ? "stop.fill" : "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .contentTransition(.symbolEffect(.replace, options: .speed(2)))
                            .foregroundStyle(isResponding || canSend ? theme.onColor : .white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isResponding || canSend ? theme.color : Color.gray.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isResponding ? "Stop" : "Send")
                    .disabled(!isResponding && !canSend)
                    .sensoryFeedback(.impact(weight: .medium), trigger: isResponding)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22, style: .continuous))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
            .background(alignment: .bottom) {
                Group {
                    if attachment != nil || openedMode != nil {
                        GlassEffectContainer(spacing: 2) {
                            HStack(spacing: 10) {
                                if supportsImages && images.count < maxImages {
                                    choice("Photos", systemImage: "photo.on.rectangle", mode: .photos)
                                    if Self.isCameraAvailable {
                                        choice("Camera", systemImage: "camera", mode: .camera)
                                    }
                                }
                                if files.count < maxFiles {
                                    fileChoice
                                }
                            }
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { rowFrame = $0 }
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { rowBottom = $0 }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if isFocused.wrappedValue {
                        ScrollView(.horizontal) {
                            GlassEffectContainer(spacing: 2) {
                                HStack(spacing: 10) {
                                    ForEach(shortcuts) { shortcut in
                                        PromptOption(
                                            title: shortcut.name,
                                            symbol: shortcut.symbol,
                                            isSelected: Binding(
                                                get: { selectedShortcuts.contains(shortcut.id) },
                                                set: { isOn in
                                                    if isOn {
                                                        selectedShortcuts.insert(shortcut.id)
                                                    } else {
                                                        selectedShortcuts.remove(shortcut.id)
                                                    }
                                                }
                                            )
                                        )
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .scrollClipDisabled()
                        .excludedFromSideMenu("shortcuts")
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.bottom, barHeight + rowGap)
            }
        }
        .coordinateSpace(.named(space))
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                attachmentCard
                attachmentPanels
            }
        }
        .padding(.horizontal)
        .padding(.bottom, isFocused.wrappedValue ? rowGap : 2)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.24), value: isFocused.wrappedValue)
        .animation(.easeInOut(duration: 0.2), value: images)
        .animation(.easeInOut(duration: 0.2), value: files)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: FileAttachment.contentTypes, allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let acceptsImages = supportsImages
            Task {
                let imported = await Task.detached { Self.importFiles(urls, acceptsImages: acceptsImages) }.value
                images += imported.images.prefix(max(0, maxImages - images.count))
                files += imported.files.prefix(max(0, maxFiles - files.count))
                isFocused.wrappedValue = true
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .animation(.easeInOut(duration: 0.24), value: attachment)
        .onChange(of: attachment) { _, mode in
            if mode == .photos || mode == .camera {
                if mode == .photos {
                    isFocused.wrappedValue = false
                }
                openedMode = mode
                withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
                    isExpanded = true
                } completion: {
                    guard isExpanded else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        isContentVisible = true
                    }
                }
            } else if openedMode != nil {
                withAnimation(.easeIn(duration: 0.1)) {
                    isContentVisible = false
                }
                withAnimation(.spring(duration: 0.32, bounce: 0.05)) {
                    isExpanded = false
                } completion: {
                    guard !isExpanded else { return }
                    withAnimation(.easeInOut(duration: 0.24)) {
                        openedMode = nil
                    }
                }
            }
        }
    }

    private var panelFrame: CGRect {
        let cover = rowGap + barHeight
        let height = min(620, max(260, rowBottom + cover - 120))
        return CGRect(x: rowFrame.minX, y: rowFrame.maxY + cover - height, width: rowFrame.width, height: height)
    }

    @ViewBuilder
    private var attachmentCard: some View {
        if let openedMode, let start = choiceFrames[openedMode] {
            let frame = isExpanded ? panelFrame : start
            let shape = RoundedRectangle(cornerRadius: isExpanded ? 34 : start.height / 2, style: .continuous)

            Color.clear
                .frame(width: frame.width, height: frame.height)
                .glassEffect(.regular, in: shape)
                .offset(x: frame.minX, y: frame.minY)
        }
    }

    @ViewBuilder
    private var attachmentPanels: some View {
        if attachment != nil, rowFrame != .zero {
            ZStack {
                panel(.photos)
                if Self.isCameraAvailable && (AVCaptureDevice.authorizationStatus(for: .video) == .authorized || openedMode == .camera) {
                    panel(.camera)
                }
            }
            .frame(width: panelFrame.width, height: panelFrame.height)
            .offset(x: panelFrame.minX, y: panelFrame.minY)
        }
    }

    private func panel(_ mode: AttachmentMode) -> some View {
        let isVisible = openedMode == mode && isContentVisible
        return AttachmentPanel(mode: mode, maxSelection: max(1, maxImages - images.count)) { data in
            add([data])
        } onPick: { items in
            attachment = nil
            isFocused.wrappedValue = true
            Task {
                add(await Self.load(items))
            }
        } onClose: {
            attachment = .choosing
        }
        .clipShape(.rect(cornerRadius: 34, style: .continuous))
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
    }

    private func closeAttachmentsInstantly() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            attachment = nil
            openedMode = nil
            isExpanded = false
            isContentVisible = false
        }
    }

    private func add(_ data: [Data]) {
        images += data.prefix(max(0, maxImages - images.count))
        attachment = nil
        isFocused.wrappedValue = true
    }

    private nonisolated static func load(_ items: [PhotosPickerItem]) async -> [Data] {
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    let data = try? await item.loadTransferable(type: Data.self)
                    return (index, data?.preparedForModel())
                }
            }
            var results: [(Int, Data?)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
    }

    private var fileChoice: some View {
        Button {
            closeAttachmentsInstantly()
            isImporting = true
        } label: {
            Label("Files", systemImage: "doc")
                .foregroundStyle(.primary)
                .opacity(isExpanded ? 0 : 1)
                .frame(maxWidth: .infinity)
                .padding(8)
                .glassEffect(isExpanded ? .identity : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(openedMode == nil)
    }

    private nonisolated static func importFiles(_ urls: [URL], acceptsImages: Bool) -> (images: [Data], files: [FileAttachment]) {
        var images: [Data] = []
        var files: [FileAttachment] = []
        for url in urls {
            if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
                guard acceptsImages else { continue }
                let isScoped = url.startAccessingSecurityScopedResource()
                if let data = try? Data(contentsOf: url).preparedForModel() {
                    images.append(data)
                }
                if isScoped { url.stopAccessingSecurityScopedResource() }
            } else if let file = FileAttachment.read(url) {
                files.append(file)
            }
        }
        return (images, files)
    }

    private func choice(_ title: LocalizedStringKey, systemImage: String, mode: AttachmentMode) -> some View {
        Button {
            attachment = mode
        } label: {
            let isHidden = openedMode == mode || isExpanded
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
                .opacity(isHidden ? 0 : 1)
                .frame(maxWidth: .infinity)
                .padding(8)
                .glassEffect(isHidden ? .identity : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(openedMode == nil)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { choiceFrames[mode] = $0 }
    }
}

enum AttachmentMode {
    case choosing
    case photos
    case camera
}

private struct FileChip: View {
    let file: FileAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 10, style: .continuous))

            Text(file.name)
                .font(.footnote.weight(.medium))
                .lineLimit(2)
                .frame(maxWidth: 140, alignment: .leading)
        }
        .padding(.leading, 14)
        .padding(.trailing, 22)
        .frame(height: 64)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            RemoveButton(action: onRemove)
        }
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.6))
        }
        .buttonStyle(.plain)
        .padding(4)
    }
}

private struct AttachmentThumbnail: View {
    let data: Data

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct AttachmentPanel: View {
    let mode: AttachmentMode
    let maxSelection: Int
    let onCapture: (Data) -> Void
    let onPick: ([PhotosPickerItem]) -> Void
    let onClose: () -> Void
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        if mode == .camera {
            CameraPicker(onCapture: onCapture, onClose: onClose)
        } else {
            VStack(spacing: 0) {
                PhotosPicker("Photos", selection: $photoItems, maxSelectionCount: maxSelection, selectionBehavior: .continuousAndOrdered, matching: .images)
                    .photosPickerStyle(.inline)
                    .photosPickerDisabledCapabilities(.selectionActions)
                    .photosPickerAccessoryVisibility(.hidden)

                HStack {
                    PanelButton(systemImage: "chevron.left", action: onClose)

                    Spacer()

                    Button {
                        onPick(photoItems)
                        photoItems = []
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(photoItems.isEmpty ? 0.5 : 1)
                    .opacity(photoItems.isEmpty ? 0 : 1)
                    .animation(.spring(duration: 0.25), value: photoItems.isEmpty)
                }
                .padding(12)
            }
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var selectedShortcuts: Set<UUID> = []
    @Previewable @State var images: [Data] = []
    @Previewable @State var attachment: AttachmentMode?
    @Previewable @FocusState var isFocused: Bool

    ChatInputView(
        text: $text,
        shortcuts: Shortcut.defaults(),
        selectedShortcuts: $selectedShortcuts,
        images: $images,
        files: .constant([]),
        supportsImages: true,
        isFocused: $isFocused,
        attachment: $attachment,
        errorMessage: nil,
        isResponding: false,
        isEditing: false,
        canSend: !text.isEmpty,
        onSend: {},
        onStop: {},
        onCancelEdit: {}
    )
}
