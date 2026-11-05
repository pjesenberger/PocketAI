//
//  SideMenu.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 13/10/2026.
//

import SwiftUI

struct SideMenu<Menu: View, Content: View>: View {
    @Binding var isOpen: Bool
    let isSidebar: Bool
    let menu: Menu
    let content: Content
    @State private var dragOffset: CGFloat = 0
    @State private var isHorizontalDrag: Bool?
    @State private var exclusion = SideMenuExclusion()
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 44

    init(isOpen: Binding<Bool>, isSidebar: Bool = false, @ViewBuilder menu: () -> Menu, @ViewBuilder content: () -> Content) {
        _isOpen = isOpen
        self.isSidebar = isSidebar
        self.menu = menu()
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let width = isSidebar ? Self.foldOffset(in: proxy) ?? 320 : min(proxy.size.width - 72, 380)
            let offset = min(max((isOpen ? width : 0) + dragOffset, 0), width)
            let progress = offset / width

            ZStack(alignment: .leading) {
                menuLayer(width: width, progress: progress)
                    .environment(\.sideMenuTopInset, proxy.safeAreaInsets.top)
                    .opacity(offset > 0 ? 1 : 0)
                    .allowsHitTesting(offset > 0)
                    .zIndex(0)
                contentLayer(width: width, offset: offset, progress: progress)
                    .zIndex(1)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)
    }

    private static func foldOffset(in proxy: GeometryProxy) -> CGFloat? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.midX > proxy.size.width * 0.25 && $0.midX < proxy.size.width * 0.75 }
        return fold.map { $0.minX }
    }

        private func menuLayer(width: CGFloat, progress: CGFloat) -> some View {
        menu
            .frame(width: width)
            .scaleEffect(0.98 + 0.02 * progress)
            .overlay {
                Color.black
                    .opacity(0.6 * (1 - progress))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
    }

    private func contentLayer(width: CGFloat, offset: CGFloat, progress: CGFloat) -> some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: .fixed(isSidebar ? 0 : cornerRadius)), isUniform: false)

        return ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            content
                .scrollIndicators(offset > 0 ? .hidden : .automatic)
                .environment(\.sideMenuExclusion, exclusion)
        }
            .compositingGroup()
            .mask {
                shape.ignoresSafeArea()
            }
            .overlay {
                shape
                    .stroke(Color.primary.opacity(offset > 0 ? (colorScheme == .dark ? 0.2 : 0.12) : 0), lineWidth: 0.5)
                    .background(shape.fill(tint(progress: progress)).opacity(offset > 0 ? 1 : 0))
                    .ignoresSafeArea(.container)
                    .allowsHitTesting(isOpen && !isSidebar)
                    .onTapGesture { setOpen(false) }
            }
            .padding(.leading, isSidebar ? offset : 0)
            .offset(x: isSidebar ? 0 : offset)
            .simultaneousGesture(dragGesture(width: width), isEnabled: !isSidebar)
    }

    private func tint(progress: CGFloat) -> some ShapeStyle {
        if isSidebar {
            return AnyShapeStyle(.clear)
        }
        if colorScheme == .dark {
            return AnyShapeStyle(Color(white: 0.1 * progress).blendMode(.lighten))
        }
        return AnyShapeStyle(Color(white: 1 - 0.05 * progress).blendMode(.darken))
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                if isHorizontalDrag == nil {
                    if !isOpen && exclusion.frames.values.contains(where: { $0.contains(value.startLocation) }) {
                        isHorizontalDrag = false
                        return
                    }
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                    if isHorizontalDrag == true {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                guard isHorizontalDrag == true else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                defer { isHorizontalDrag = nil }
                guard isHorizontalDrag == true else { return }
                let end = (isOpen ? width : 0) + value.predictedEndTranslation.width
                setOpen(end > width / 2)
            }
    }

    private func setOpen(_ open: Bool) {
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            isOpen = open
            dragOffset = 0
        }
    }
}

final class SideMenuExclusion {
    var frames: [String: CGRect] = [:]
}

extension EnvironmentValues {
    @Entry var sideMenuExclusion: SideMenuExclusion?
    @Entry var sideMenuTopInset: CGFloat = 0
}

extension View {
    func excludedFromSideMenu(_ id: String) -> some View {
        modifier(SideMenuExcluded(id: id))
    }
}

private struct SideMenuExcluded: ViewModifier {
    @Environment(\.sideMenuExclusion) private var exclusion
    let id: String

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { exclusion?.frames[id] = $0 }
            .onDisappear { exclusion?.frames[id] = nil }
    }
}
