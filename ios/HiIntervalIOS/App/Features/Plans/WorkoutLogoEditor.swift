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
    @State private var cropPhoto: CropPhoto?

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
        .sheet(item: $cropPhoto, onDismiss: { selectedPhoto = nil }) { photo in
            WorkoutLogoCropView(photo: photo, imageStore: imageStore) { croppedData in
                draft.setPendingPhotoData(croppedData)
                photoError = nil
                cropPhoto = nil
            }
        }
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
                    guard let image = UIImage(data: prepared) else {
                        photoError = WorkoutLogoImageStore.StoreError.invalidImage.localizedDescription
                        isLoadingPhoto = false
                        return
                    }
                    cropPhoto = CropPhoto(data: prepared, image: image)
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
        cropPhoto = nil
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
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(logo.backgroundColor))
                if let pendingPhotoData, let image = UIImage(data: pendingPhotoData) {
                    logoPhoto(image, size: geometry.size)
                } else if let image = imageStore.image(for: logo.photoFilename) {
                    logoPhoto(image, size: geometry.size)
                } else {
                    Image(systemName: logo.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(logo.symbolColor))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityLabel("Workout logo")
    }

    private func logoPhoto(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

private struct CropPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let image: UIImage
}

/// Square selection stays in memory. Only the enclosing plan editor writes a chosen crop on Save.
private struct WorkoutLogoCropView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: CropPhoto
    let imageStore: WorkoutLogoImageStore
    let onUse: (Data) -> Void

    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var offsetAtGestureStart: CGSize = .zero
    @State private var cropError: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let side = max(1, min(geometry.size.width - 32, geometry.size.height * 0.48))
                ScrollView {
                    VStack(spacing: 18) {
                        cropWindow(side: side)
                        Text("Drag photo to choose the square. Pinch or use zoom controls to adjust.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) {
                                zoomOutButton(side: side)
                                zoomInButton(side: side)
                                moveMenu(side: side)
                            }
                            VStack(spacing: 12) {
                                zoomOutButton(side: side)
                                zoomInButton(side: side)
                                moveMenu(side: side)
                            }
                        }
                        if let cropError {
                            Text(cropError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("plan.editor.logo.crop.cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Photo") {
                            do {
                                let data = try imageStore.squarePhotoData(
                                    from: photo.data,
                                    viewportSide: side,
                                    zoom: zoom,
                                    offset: bounded(offset, side: side, zoom: zoom)
                                )
                                onUse(data)
                            } catch {
                                cropError = error.localizedDescription
                            }
                        }
                        .accessibilityIdentifier("plan.editor.logo.crop.use")
                    }
                }
            }
            .navigationTitle("Crop workout photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("plan.editor.logo.crop.screen")
    }

    private func cropWindow(side: CGFloat) -> some View {
        let baseScale = max(side / photo.image.size.width, side / photo.image.size.height)
        let visibleOffset = bounded(offset, side: side, zoom: zoom)
        return Image(uiImage: photo.image)
            .resizable()
            .frame(width: photo.image.size.width * baseScale * zoom,
                   height: photo.image.size.height * baseScale * zoom)
            .offset(visibleOffset)
            .frame(width: side, height: side)
            .clipped()
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture()
                .onChanged { value in
                    offset = bounded(
                        CGSize(width: offsetAtGestureStart.width + value.translation.width,
                               height: offsetAtGestureStart.height + value.translation.height),
                        side: side,
                        zoom: zoom
                    )
                }
                .onEnded { _ in offsetAtGestureStart = offset }
            )
            .simultaneousGesture(MagnificationGesture()
                .onChanged { value in
                    zoom = min(4, max(1, zoomAtGestureStart * value))
                    offset = bounded(offset, side: side, zoom: zoom)
                }
                .onEnded { _ in
                    zoomAtGestureStart = zoom
                    offsetAtGestureStart = offset
                }
            )
            .accessibilityLabel("Square photo crop")
            .accessibilityIdentifier("plan.editor.logo.crop.selection")
    }

    private func bounded(_ value: CGSize, side: CGFloat, zoom: CGFloat) -> CGSize {
        let crop = WorkoutLogoCropGeometry(
            sourceWidth: Double(photo.image.size.width),
            sourceHeight: Double(photo.image.size.height),
            viewportSide: Double(side),
            zoom: Double(zoom)
        )
        let clamped = crop.clampedOffset(x: Double(value.width), y: Double(value.height))
        return CGSize(width: clamped.x, height: clamped.y)
    }

    private func zoomOutButton(side: CGFloat) -> some View {
        Button("Zoom out", systemImage: "minus.magnifyingglass") {
            setZoom(zoom - 0.25, side: side)
        }
        .disabled(zoom <= 1)
        .accessibilityIdentifier("plan.editor.logo.crop.zoom-out")
    }

    private func zoomInButton(side: CGFloat) -> some View {
        Button("Zoom in", systemImage: "plus.magnifyingglass") {
            setZoom(zoom + 0.25, side: side)
        }
        .disabled(zoom >= 4)
        .accessibilityIdentifier("plan.editor.logo.crop.zoom-in")
    }

    private func moveMenu(side: CGFloat) -> some View {
        Menu("Move photo", systemImage: "arrow.up.left.and.arrow.down.right") {
            Button("Move left") { movePhoto(x: -side / 8, y: 0, side: side) }
            Button("Move right") { movePhoto(x: side / 8, y: 0, side: side) }
            Button("Move up") { movePhoto(x: 0, y: -side / 8, side: side) }
            Button("Move down") { movePhoto(x: 0, y: side / 8, side: side) }
        }
        .accessibilityIdentifier("plan.editor.logo.crop.move")
    }

    private func setZoom(_ value: CGFloat, side: CGFloat) {
        zoom = min(4, max(1, value))
        zoomAtGestureStart = zoom
        offset = bounded(offset, side: side, zoom: zoom)
        offsetAtGestureStart = offset
    }

    private func movePhoto(x: CGFloat, y: CGFloat, side: CGFloat) {
        offset = bounded(CGSize(width: offset.width + x, height: offset.height + y), side: side, zoom: zoom)
        offsetAtGestureStart = offset
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
