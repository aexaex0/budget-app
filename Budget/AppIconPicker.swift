import SwiftUI
import UIKit

/// Alkalmazás ikon választó (az ikonok az Assets-ben vannak).
struct AppIconPicker: View {
    @State private var current: String? = UIApplication.shared.alternateIconName

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    private func iconName(_ n: Int) -> String? {
        n == 1 ? nil : String(format: "AppIcon%02d", n)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...8, id: \.self) { n in
                let name = iconName(n)
                let selected = current == name
                Button {
                    Haptics.tap()
                    UIApplication.shared.setAlternateIconName(name) { error in
                        if error == nil { current = name }
                    }
                } label: {
                    Image(String(format: "Preview%02d", n))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.white, Color.accentColor)
                                    .offset(x: 4, y: 4)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
