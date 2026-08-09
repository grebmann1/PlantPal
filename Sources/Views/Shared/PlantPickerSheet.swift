import SwiftUI

struct PlantPickerSheet: View {
    let plants: [Plant]
    let title: String
    var onSelect: (Plant) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            List(plants) { plant in
                Button {
                    onSelect(plant)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        RemotePhoto(path: plant.photoUrl)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radius.sm))
                        VStack(alignment: .leading) {
                            Text(plant.nickname).font(theme.headlineFont).foregroundStyle(theme.textPrimary)
                            Text(plant.speciesLatinName ?? "").font(theme.footnoteFont).italic().foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
