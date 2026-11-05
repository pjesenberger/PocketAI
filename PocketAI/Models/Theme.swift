//
//  Theme.swift
//  PocketAI
//
//  Created by Pascal Jesenberger on 14/10/2026.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case blue, cyan, green, orange, pink, purple, white

    var id: String { rawValue }

    var name: String {
        switch self {
        case .blue: String(localized: "Blue")
        case .cyan: String(localized: "Cyan")
        case .green: String(localized: "Green")
        case .orange: String(localized: "Orange")
        case .pink: String(localized: "Pink")
        case .purple: String(localized: "Purple")
        case .white: String(localized: "White")
        }
    }

    var color: Color {
        switch self {
        case .blue: .blue
        case .cyan: .cyan
        case .green: Color(hex: 0x28A745)
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        case .white: .white
        }
    }

    var tint: Color {
        self == .white ? .white.opacity(0.2) : color
    }

    var onColor: Color {
        self == .white ? .black : .white
    }
}

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case white, blue, retro, magistral, pocket64

    var id: String { rawValue }

    var name: String {
        switch self {
        case .white: String(localized: "White")
        case .blue: String(localized: "Blue")
        case .retro: String(localized: "Retro")
        case .magistral: "Magistral"
        case .pocket64: "Pocket64"
        }
    }

    var iconName: String? {
        self == .white ? nil : "AppIcon-\(rawValue.capitalized)"
    }

    static var current: AppIconOption {
        allCases.first { $0.iconName == UIApplication.shared.alternateIconName } ?? .white
    }

    static let background = Color(.displayP3, red: 0.0868, green: 0.0862, blue: 0.116)

    var colors: [Color] {
        let hex: [UInt32] = switch self {
        case .magistral: [0xFFAB00, 0xFF7B00, 0xFF3B00, 0xFA0000, 0xD40009, 0xB00007]
        case .blue: [0x68E3FF, 0x3CC0F3, 0x0BA0E2, 0x0080CF, 0x005EBC, 0x033BA6]
        case .retro: [0x8FE36B, 0x5FCF4A, 0x3BB33A, 0x2A9435, 0x1E7A2F, 0x155F28]
        case .pocket64: [0xE2231A, 0xF7941D, 0xFFF200, 0x00A651, 0x00AEEF, 0x0072BC]
        case .white: [0xFFFFFF, 0xE6E6E6, 0xCCCCCC, 0xB3B3B3, 0x999999, 0x808080]
        }
        return hex.map(Color.init(hex:))
    }
}

struct PocketGlyph: View {
    let option: AppIconOption
    var size: CGFloat = 28

    var body: some View {
        PixelArt(rects: Self.rects, colors: option.colors, size: size)
    }

    private static let rects: [(CGRect, Int)] = [
        (CGRect(x: 0, y: 195, width: 149, height: 39), 5),
        (CGRect(x: 39, y: 146, width: 78, height: 63), 4),
        (CGRect(x: 39, y: 0, width: 78, height: 72), 0),
        (CGRect(x: 39, y: 16, width: 78, height: 77), 1),
        (CGRect(x: 176, y: 39, width: 58, height: 54), 1),
        (CGRect(x: 156, y: 21, width: 39, height: 72), 1),
        (CGRect(x: 156, y: 78, width: 78, height: 39), 2),
        (CGRect(x: 156, y: 78, width: 39, height: 57), 2),
        (CGRect(x: 39, y: 78, width: 78, height: 48), 2),
        (CGRect(x: 39, y: 195, width: 117, height: 39), 5),
        (CGRect(x: 39, y: 117, width: 156, height: 39), 3),
        (CGRect(x: 0, y: 0, width: 195, height: 39), 0),
        (CGRect(x: 39, y: 156, width: 39, height: 39), 4),
        (CGRect(x: 78, y: 78, width: 39, height: 39), 2)
    ]
}

struct IncognitoGlyph: View {
    var option: AppIconOption = .white
    var color: Color?
    var size: CGFloat = 28

    var body: some View {
        PixelArt(rects: Self.rects, colors: color.map { Array(repeating: $0, count: 6) } ?? option.colors, size: size)
    }

    private static let rects: [(CGRect, Int)] = [
        (CGRect(x: 195, y: 67, width: 39, height: 66), 2),
        (CGRect(x: 156, y: 67, width: 39, height: 66), 2),
        (CGRect(x: 78, y: 69, width: 39, height: 61), 2),
        (CGRect(x: 0, y: 67, width: 39, height: 66), 2),
        (CGRect(x: 0, y: 117, width: 232, height: 49), 3),
        (CGRect(x: 0, y: 156, width: 39, height: 50), 4),
        (CGRect(x: 0, y: 195, width: 39, height: 39), 5),
        (CGRect(x: 106, y: 174, width: 50, height: 60), 5),
        (CGRect(x: 78, y: 187, width: 39, height: 47), 5),
        (CGRect(x: 156, y: 117, width: 39, height: 39), 3),
        (CGRect(x: 117, y: 117, width: 39, height: 39), 3),
        (CGRect(x: 78, y: 117, width: 39, height: 39), 3),
        (CGRect(x: 39, y: 117, width: 39, height: 39), 3),
        (CGRect(x: 156, y: 0, width: 39, height: 39), 0),
        (CGRect(x: 117, y: 0, width: 39, height: 39), 0),
        (CGRect(x: 78, y: 0, width: 39, height: 39), 0),
        (CGRect(x: 39, y: 0, width: 156, height: 57), 0),
        (CGRect(x: 78, y: 156, width: 39, height: 39), 4),
        (CGRect(x: 117, y: 156, width: 39, height: 39), 4),
        (CGRect(x: 156, y: 156, width: 39, height: 39), 4),
        (CGRect(x: 195, y: 180, width: 39, height: 54), 5),
        (CGRect(x: 195, y: 117, width: 39, height: 39), 3),
        (CGRect(x: 24, y: 156, width: 210, height: 39), 4),
        (CGRect(x: 39, y: 156, width: 39, height: 39), 4),
        (CGRect(x: 78, y: 39, width: 39, height: 39), 1),
        (CGRect(x: 117, y: 39, width: 39, height: 39), 1),
        (CGRect(x: 39, y: 39, width: 39, height: 39), 1),
        (CGRect(x: 0, y: 39, width: 39, height: 39), 1),
        (CGRect(x: 24, y: 39, width: 210, height: 39), 1),
        (CGRect(x: 156, y: 39, width: 39, height: 39), 1)
    ]
}

private struct PixelArt: View {
    let rects: [(CGRect, Int)]
    let colors: [Color]
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 234
            for (rect, index) in rects {
                let frame = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
                context.fill(Path(frame), with: .color(colors[index]))
            }
        }
        .frame(width: size, height: size)
    }
}

struct AppIconPreview: View {
    let option: AppIconOption
    var size: CGFloat = 60

    var body: some View {
        PocketGlyph(option: option, size: size * 0.594)
            .frame(width: size, height: size)
            .background(AppIconOption.background)
            .clipShape(.rect(cornerRadius: size * 0.225, style: .continuous))
    }
}

struct MenuIcon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4.5) {
            Capsule()
                .fill(Color.primary)
                .frame(width: 18, height: 2.5)
            Capsule()
                .fill(Color.primary)
                .frame(width: 11, height: 2.5)
        }
        .frame(width: 22, height: 22)
        .accessibilityLabel("Menu")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ModelIcon: View {
    let model: AIModel
    var size: CGFloat = 28

    var body: some View {
        logo
            .frame(width: size, height: size)
            .background(.white, in: .rect(cornerRadius: size * 0.28, style: .continuous))
    }

    @ViewBuilder
    private var logo: some View {
        if let asset = model.logo {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.58, height: size * 0.58)
        } else if model.isCustom {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.black)
        } else {
            Image(systemName: "apple.intelligence")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.orange, .pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

extension View {
    func card() -> some View {
        background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 22, style: .continuous))
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
    }
}
