//
//  HintPhotoViews.swift
//  BokuNoTakarasagashi
//

import CoreTransferable
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PhotoPreparationTracker {
    private var activeSourceIDs: Set<UUID> = []

    var isPreparing: Bool {
        !activeSourceIDs.isEmpty
    }

    mutating func setPreparing(_ isPreparing: Bool, for sourceID: UUID) {
        if isPreparing {
            activeSourceIDs.insert(sourceID)
        } else {
            activeSourceIDs.remove(sourceID)
        }
    }
}

struct HintPhotoEditor: View {
    @Binding var imageData: Data?
    var photoAccessibilityLabel = "ヒントの写真"
    var onPreparationStateChange: (Bool) -> Void = { _ in }

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var preparationTask: Task<Void, Never>?
    @State private var preparationRequestID: UUID?

    var body: some View {
        let photoPickerTitle = imageData == nil
            ? "写真を選ぶ"
            : "写真を変更"

        VStack(alignment: .leading, spacing: 12) {
            if let imageData {
                HintPhotoView(
                    data: imageData,
                    maxHeight: 220,
                    accessibilityLabel: photoAccessibilityLabel
                )
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("写真を準備しています…")
                        .font(.footnote)
                        .foregroundStyle(TreasureTheme.secondaryText)
                }
            }

            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    preferredItemEncoding: .compatible
                ) {
                    Label(
                        photoPickerTitle,
                        systemImage: "photo.on.rectangle"
                    )
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("撮影", systemImage: "camera.fill")
                    }
                }

                if imageData != nil {
                    Spacer()

                    Button(role: .destructive) {
                        imageData = nil
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    .tint(TreasureTheme.coralText)
                }
            }
            .buttonStyle(.bordered)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            loadPhoto(from: newItem)
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraImagePicker { image in
                prepareCameraPhoto(image)
            }
            .ignoresSafeArea()
        }
        .alert("写真を追加できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "別の写真でもう一度ためしてください。")
        }
        .onDisappear {
            cancelPhotoPreparation()
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        let requestID = beginPhotoPreparation()

        preparationTask = Task {
            do {
                guard let sourceFile = try await item.loadTransferable(
                    type: SelectedPhotoFile.self
                ) else {
                    throw HintPhotoProcessingError.unreadable
                }
                defer {
                    try? FileManager.default.removeItem(at: sourceFile.url)
                }
                let preparedData = try await Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try HintPhotoProcessor.storedData(from: sourceFile.url)
                }.value
                try Task.checkCancellation()
                finishPhotoPreparation(requestID, with: .success(preparedData))
            } catch is CancellationError {
                finishPhotoPreparation(requestID, with: nil)
            } catch {
                finishPhotoPreparation(requestID, with: .failure(error))
            }
        }
    }

    private func prepareCameraPhoto(_ image: UIImage) {
        let requestID = beginPhotoPreparation()

        preparationTask = Task {
            do {
                let preparedData = try await Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try HintPhotoProcessor.storedData(from: image)
                }.value
                try Task.checkCancellation()
                finishPhotoPreparation(requestID, with: .success(preparedData))
            } catch is CancellationError {
                finishPhotoPreparation(requestID, with: nil)
            } catch {
                finishPhotoPreparation(requestID, with: .failure(error))
            }
        }
    }

    private func beginPhotoPreparation() -> UUID {
        preparationTask?.cancel()
        let requestID = UUID()
        preparationRequestID = requestID
        setLoading(true)
        errorMessage = nil
        return requestID
    }

    private func finishPhotoPreparation(
        _ requestID: UUID,
        with result: Result<Data, Error>?
    ) {
        guard preparationRequestID == requestID else { return }
        defer {
            selectedItem = nil
            preparationTask = nil
            preparationRequestID = nil
            setLoading(false)
        }

        switch result {
        case .success(let data):
            imageData = data
        case .failure(let error):
            errorMessage = error.localizedDescription
        case nil:
            break
        }
    }

    private func cancelPhotoPreparation() {
        preparationTask?.cancel()
        selectedItem = nil
        preparationTask = nil
        preparationRequestID = nil
        setLoading(false)
    }

    private func setLoading(_ newValue: Bool) {
        guard isLoading != newValue else { return }
        isLoading = newValue
        onPreparationStateChange(newValue)
    }
}

private nonisolated struct SelectedPhotoFile: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { receivedFile in
            try HintPhotoProcessor.validateInputFile(at: receivedFile.file)

            let fileExtension = receivedFile.file.pathExtension
            var destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "HintPhoto-\(UUID().uuidString)",
                    isDirectory: false
                )
            if !fileExtension.isEmpty {
                destinationURL.appendPathExtension(fileExtension)
            }
            try FileManager.default.copyItem(
                at: receivedFile.file,
                to: destinationURL
            )
            return SelectedPhotoFile(url: destinationURL)
        }
    }
}

struct HintPhotoView: View {
    let data: Data
    var maxHeight: CGFloat = 280
    var accessibilityLabel = "ヒントの写真"

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(TreasureTheme.ink.opacity(0.08), lineWidth: 1)
                }
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

nonisolated enum HintPhotoProcessor {
    static let maximumInputByteCount = 50 * 1_024 * 1_024
    private static let maximumPixelCount = 100_000_000
    private static let maximumDimension = 1_600
    private static let maximumStoredByteCount =
        TreasureContentLimits.maximumStagePhotoByteCount

    nonisolated static func storedData(from data: Data) throws -> Data {
        guard !data.isEmpty,
              data.count <= maximumInputByteCount else {
            throw HintPhotoProcessingError.tooLarge
        }

        let sourceOptions = [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            sourceOptions
        ) else {
            throw HintPhotoProcessingError.unreadable
        }
        return try storedData(from: source, sourceOptions: sourceOptions)
    }

    nonisolated static func storedData(from url: URL) throws -> Data {
        try validateInputFile(at: url)

        let sourceOptions = [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            sourceOptions
        ) else {
            throw HintPhotoProcessingError.unreadable
        }
        return try storedData(from: source, sourceOptions: sourceOptions)
    }

    nonisolated static func validateInputFile(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= maximumInputByteCount else {
            throw HintPhotoProcessingError.tooLarge
        }
    }

    nonisolated private static func storedData(
        from source: CGImageSource,
        sourceOptions: CFDictionary
    ) throws -> Data {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            sourceOptions
        ) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
        let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            throw HintPhotoProcessingError.unreadable
        }

        let pixelWidth = width.intValue
        let pixelHeight = height.intValue
        guard pixelWidth > 0,
              pixelHeight > 0,
              pixelWidth <= maximumPixelCount / pixelHeight else {
            throw HintPhotoProcessingError.tooLarge
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions
        ) else {
            throw HintPhotoProcessingError.unreadable
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw HintPhotoProcessingError.unreadable
        }
        let destinationOptions = [
            kCGImageDestinationLossyCompressionQuality: 0.82,
        ] as CFDictionary
        CGImageDestinationAddImage(
            destination,
            thumbnail,
            destinationOptions
        )
        guard CGImageDestinationFinalize(destination) else {
            throw HintPhotoProcessingError.unreadable
        }

        let result = output as Data
        guard result.count <= maximumStoredByteCount else {
            throw HintPhotoProcessingError.tooLarge
        }
        return result
    }

    nonisolated static func storedData(from image: UIImage) throws -> Data {
        guard image.size.width > 0,
              image.size.height > 0,
              let sourceData = image.jpegData(compressionQuality: 0.95) else {
            throw HintPhotoProcessingError.unreadable
        }
        return try storedData(from: sourceData)
    }
}

nonisolated enum HintPhotoProcessingError: LocalizedError {
    case tooLarge
    case unreadable

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            return "写真が大きすぎます。別の写真を選んでください。"
        case .unreadable:
            return "写真を読み込めませんでした。別の写真でもう一度ためしてください。"
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImage: onImage,
            onDismiss: { dismiss() }
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onDismiss: () -> Void

        init(
            onImage: @escaping (UIImage) -> Void,
            onDismiss: @escaping () -> Void
        ) {
            self.onImage = onImage
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }
    }
}
