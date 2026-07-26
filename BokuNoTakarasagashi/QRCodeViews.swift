//
//  QRCodeViews.swift
//  BokuNoTakarasagashi
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import Vision
import VisionKit

enum QRCodeScannerCapability {
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    static var isCurrentlyAvailable: Bool {
        isSupported && DataScannerViewController.isAvailable
    }
}

struct QRCodePreparationView: View {
    let payload: String
    let treasureNumber: Int
    let isPrepared: Bool
    let onPrepared: (() -> Void)?

    @State private var isShowingShareSheet = false

    init(
        payload: String,
        treasureNumber: Int,
        isPrepared: Bool = false,
        onPrepared: (() -> Void)? = nil
    ) {
        self.payload = payload
        self.treasureNumber = treasureNumber
        self.isPrepared = isPrepared
        self.onPrepared = onPrepared
    }

    private var qrCodeImage: UIImage? {
        QRCodeImageGenerator.makeImage(payload: payload)
    }

    var body: some View {
        TreasureBackground(style: .preparation) {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 7) {
                        Text("宝 \(treasureNumber) のQRコード")
                            .font(.title2.bold())
                            .foregroundStyle(TreasureTheme.ink)

                        Text("印刷するか、別の端末へ送って\n宝といっしょに置いてください。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    if let qrCodeImage {
                        Image(uiImage: qrCodeImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .padding(18)
                            .background(.white, in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityLabel("宝 \(treasureNumber) のQRコード")
                            .treasureCard()

                        Button {
                            isShowingShareSheet = true
                        } label: {
                            Label("画像を共有・印刷", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(TreasurePrimaryButtonStyle())

                        if let onPrepared {
                            Button(action: onPrepared) {
                                Label(
                                    isPrepared
                                        ? "QRコードを用意しました"
                                        : "印刷・保存・別端末への準備ができた",
                                    systemImage: isPrepared
                                        ? "checkmark.circle.fill"
                                        : "circle"
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(isPrepared ? TreasureTheme.teal : TreasureTheme.ink)
                            .disabled(isPrepared)
                        }
                    } else {
                        ContentUnavailableView(
                            "QRコードを作れませんでした",
                            systemImage: "qrcode",
                            description: Text("画面を閉じて、もう一度ためしてください。")
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("このiPhoneだけで遊ぶ場合", systemImage: "iphone")
                            .font(.headline)
                            .foregroundStyle(TreasureTheme.ink)

                        Text("共有メニューから「プリント」または「写真に保存」を選びます。写真に保存した場合は、別の端末に表示する必要があります。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .treasureCard()
                }
                .padding(20)
            }
        }
        .navigationTitle("QRコードの準備")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShareSheet) {
            if let qrCodeImage {
                ShareSheet(activityItems: [qrCodeImage])
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

struct QRCodeScannerView: View {
    let expectedPayload: String
    let onMatch: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackMessage: String?
    @State private var mismatchCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                if QRCodeScannerCapability.isCurrentlyAvailable {
                    QRDataScannerView(
                        onCode: handle,
                        onError: { message in
                            feedbackMessage = message
                        }
                    )
                    .ignoresSafeArea()

                    scannerOverlay
                } else {
                    TreasureBackground(style: .preparation) {
                        ContentUnavailableView {
                            Label("カメラを使えません", systemImage: "camera.fill")
                        } description: {
                            Text("設定でカメラを許可するか、対応するiPhoneでためしてください。")
                        }
                    }
                }
            }
            .navigationTitle("QRコードをさがす")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sensoryFeedback(.error, trigger: mismatchCount)
    }

    private var scannerOverlay: some View {
        VStack(spacing: 16) {
            Text("宝といっしょにあるQRコードを\n四角の中に入れてね")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.black.opacity(0.62), in: Capsule())

            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .stroke(TreasureTheme.gold, style: StrokeStyle(lineWidth: 5, dash: [18, 10]))
                .frame(width: 270, height: 270)
                .shadow(color: .black.opacity(0.35), radius: 8)
                .accessibilityHidden(true)

            Spacer()

            if let feedbackMessage {
                Label(feedbackMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                    .background(TreasureTheme.coral.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
            } else {
                Text("QRコードを読み取ると、自動で次へ進みます")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.58), in: Capsule())
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 32)
    }

    private func handle(_ candidate: String) -> Bool {
        if TreasurePayload.matches(candidate, expected: expectedPayload) {
            onMatch()
            dismiss()
            return true
        }

        feedbackMessage = "これは別の宝のQRコードみたい"
        mismatchCount += 1
        return false
    }
}

private struct QRDataScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Bool
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.qr]),
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        Task { @MainActor in
            do {
                try scanner.startScanning()
            } catch {
                onError("カメラを開始できませんでした")
            }
        }
        return scanner
    }

    func updateUIViewController(
        _ uiViewController: DataScannerViewController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ uiViewController: DataScannerViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCode: (String) -> Bool
        private let onError: (String) -> Void
        private var didMatch = false
        private var lastRejectedValue: String?
        private var lastRejectedAt = Date.distantPast

        init(
            onCode: @escaping (String) -> Bool,
            onError: @escaping (String) -> Void
        ) {
            self.onCode = onCode
            self.onError = onError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            dataScanner.stopScanning()
            onError(
                "カメラを利用できなくなりました。設定や利用制限を確認してください。"
            )
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didMatch else { return }

            for item in addedItems {
                guard case let .barcode(barcode) = item,
                      let value = barcode.payloadStringValue else {
                    continue
                }

                if value == lastRejectedValue,
                   Date.now.timeIntervalSince(lastRejectedAt) < 2 {
                    continue
                }

                if onCode(value) {
                    didMatch = true
                    dataScanner.stopScanning()
                    return
                }

                lastRejectedValue = value
                lastRejectedAt = .now
            }
        }
    }
}

private enum QRCodeImageGenerator {
    private static let context = CIContext()

    static func makeImage(payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let scale = floor(880 / outputImage.extent.width)
        let scaledImage = outputImage.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )

        guard let cgImage = context.createCGImage(
            scaledImage,
            from: scaledImage.extent
        ) else {
            return nil
        }

        let qrCode = UIImage(cgImage: cgImage)
        let size = CGSize(width: 1024, height: 1024)
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            UIColor.white.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
            rendererContext.cgContext.interpolationQuality = .none

            let side = scaledImage.extent.width
            let origin = (size.width - side) / 2
            qrCode.draw(in: CGRect(x: origin, y: origin, width: side, height: side))
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
