//
//  HintPhotoViews.swift
//  BokuNoTakarasagashi
//

import PhotosUI
import SwiftUI
import UIKit

struct HintPhotoEditor: View {
    @Binding var imageData: Data?
    var photoAccessibilityLabel = "ヒントの写真"

    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
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
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    preferredItemEncoding: .compatible
                ) {
                    Label(
                        imageData == nil ? "写真を選ぶ" : "写真を変更",
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
                guard let data = HintPhotoProcessor.storedData(from: image) else {
                    errorMessage = "撮影した写真を準備できませんでした。"
                    return
                }
                imageData = data
            }
            .ignoresSafeArea()
        }
        .alert("写真を追加できませんでした", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "別の写真でもう一度ためしてください。")
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
        isLoading = true
        errorMessage = nil

        Task {
            defer {
                isLoading = false
                selectedItem = nil
            }

            do {
                guard let sourceData = try await item.loadTransferable(type: Data.self),
                      let preparedData = HintPhotoProcessor.storedData(from: sourceData) else {
                    errorMessage = "選んだ写真を読み込めませんでした。"
                    return
                }
                imageData = preparedData
            } catch {
                errorMessage = "選んだ写真を読み込めませんでした。"
            }
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

private enum HintPhotoProcessor {
    private static let maximumDimension: CGFloat = 1_600

    static func storedData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return storedData(from: image)
    }

    static func storedData(from image: UIImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let longestSide = max(image.size.width, image.size.height)
        let ratio = min(1, maximumDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, (image.size.width * ratio).rounded()),
            height: max(1, (image.size.height * ratio).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let preparedImage = UIGraphicsImageRenderer(
            size: targetSize,
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return preparedImage.jpegData(compressionQuality: 0.82)
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
