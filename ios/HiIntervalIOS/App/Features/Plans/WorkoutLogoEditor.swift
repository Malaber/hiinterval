import PhotosUI
import SwiftUI
import HiIntervalCore
import UIKit

/// Reusable controls for a plan editor. The enclosing editor owns Save/Cancel and calls the image
/// store only after its full plan validates.
struct WorkoutLogoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: WorkoutLogoDraft
    @Binding var isLoadingPhoto: Bool
    let imageStore: WorkoutLogoImageStore

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoError: String?
    @State private var photoLoadToken = UUID()

    init(
        draft: Binding<WorkoutLogoDraft>,
        isLoadingPhoto: Binding<Bool>,
        imageStore: WorkoutLogoImageStore = .shared
    ) {
        _draft = draft
        _isLoadingPhoto = isLoadingPhoto
        self.imageStore = imageStore
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    WorkoutLogoMark(logo: draft.logo, pendingPhotoData: draft.pendingPhotoData, imageStore: imageStore)
                        .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.hasPhoto ? "Selected photo" : "Symbol logo")
                            .font(.headline)
                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                Picker("Symbol", selection: $draft.logo.symbolName) {
                    ForEach(Self.symbols, id: \.self) { symbol in
                        Label(symbolName(symbol), systemImage: symbol)
                            .tag(symbol)
                            .accessibilityIdentifier("plan.editor.logo.symbol.option.\(symbol)")
                    }
                }
                .accessibilityIdentifier("plan.editor.logo.symbol")

                ColorPicker("Symbol color", selection: logoColorBinding(\.symbolColor), supportsOpacity: true)
                ColorPicker("Background color", selection: logoColorBinding(\.backgroundColor), supportsOpacity: false)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(draft.hasPhoto ? "Replace photo" : "Choose photo", systemImage: "photo.on.rectangle")
                }
                .onChange(of: selectedPhoto) { _, item in
                    loadPhoto(item)
                }

                if isLoadingPhoto {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading photo…")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("plan.editor.logo.loading")
                    Button("Cancel photo import") { clearPhotoSelection() }
                        .accessibilityIdentifier("plan.editor.logo.cancel-import")
                }

                if draft.hasPhoto {
                    Button("Remove photo", role: .destructive) {
                        draft.removePhoto()
                        clearPhotoSelection()
                    }
                }

                Button("Restore default logo") {
                    draft.reset()
                    clearPhotoSelection()
                }
                .accessibilityIdentifier("plan.editor.logo.reset")
                .disabled(draft.logo == .default && draft.pendingPhotoData == nil)

                if let photoError {
                    Text(photoError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Workout logo")
                    .accessibilityIdentifier("plan.editor.logo")
            } footer: {
                Text("Photos are selected through Apple's picker. HiInterval never asks for full photo-library access.")
            }
        }
        .navigationTitle("Workout logo")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isLoadingPhoto)
        .interactiveDismissDisabled(isLoadingPhoto)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .disabled(isLoadingPhoto)
                    .accessibilityIdentifier("plan.editor.logo.done")
            }
        }
        .accessibilityIdentifier("plan.editor.logo.screen")
    }

    private static let symbols = [
        "waveform.path.ecg", "figure.run", "flame.fill", "bolt.fill", "heart.fill",
        "figure.strengthtraining.traditional", "figure.mind.and.body", "dumbbell.fill",
    ]

    private func logoColorBinding(_ keyPath: WritableKeyPath<WorkoutLogo, WorkoutLogoColor>) -> Binding<Color> {
        Binding(
            get: { Color(draft.logo[keyPath: keyPath]) },
            set: { draft.logo[keyPath: keyPath] = WorkoutLogoColor($0) }
        )
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        let token = UUID()
        photoLoadToken = token
        guard let item else {
            isLoadingPhoto = false
            return
        }
        isLoadingPhoto = true
        photoError = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw WorkoutLogoImageStore.StoreError.invalidImage
                }
                let prepared = try imageStore.preparedPhotoData(from: data)
                await MainActor.run {
                    guard photoLoadToken == token else { return }
                    draft.setPendingPhotoData(prepared)
                    photoError = nil
                    isLoadingPhoto = false
                }
            } catch {
                await MainActor.run {
                    guard photoLoadToken == token else { return }
                    photoError = error.localizedDescription
                    isLoadingPhoto = false
                }
            }
        }
    }

    private func clearPhotoSelection() {
        photoLoadToken = UUID()
        isLoadingPhoto = false
        selectedPhoto = nil
        photoError = nil
    }

    private func symbolName(_ symbol: String) -> String {
        switch symbol {
        case "waveform.path.ecg": "Pulse"
        case "figure.run": "Running"
        case "flame.fill": "Flame"
        case "bolt.fill": "Bolt"
        case "heart.fill": "Heart"
        case "figure.strengthtraining.traditional": "Strength"
        case "figure.mind.and.body": "Mind and body"
        default: "Dumbbell"
        }
    }
}

struct WorkoutLogoMark: View {
    let logo: WorkoutLogo
    var pendingPhotoData: Data? = nil
    let imageStore: WorkoutLogoImageStore

    init(logo: WorkoutLogo, pendingPhotoData: Data? = nil, imageStore: WorkoutLogoImageStore = .shared) {
        self.logo = logo
        self.pendingPhotoData = pendingPhotoData
        self.imageStore = imageStore
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(logo.backgroundColor))
            if let pendingPhotoData, let image = UIImage(data: pendingPhotoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let image = imageStore.image(for: logo.photoFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: logo.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(logo.symbolColor))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel("Workout logo")
    }
}

private extension WorkoutLogoColor {
    @MainActor
    init(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 1
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity) else {
            self = .defaultBackground
            return
        }
        self.init(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(opacity))
    }
}
