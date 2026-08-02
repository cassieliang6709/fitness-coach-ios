import PhotosUI
import SwiftUI
import UIKit

/// Optional gym-photo step inside onboarding. Recognition never silently
/// trusts an ambiguous machine: medium-confidence sightings require a tap.
struct GymPhotoScanner: View {
    @Bindable var vision: GymVision
    let goal: String

    @State private var libraryItem: PhotosPickerItem?
    @State private var preview: UIImage?
    @State private var showingCamera = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.lightOrange)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.primary)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("拍下你常用的器械")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    Text("Kimi 只记录能确认的器械；看不清的会先问你。")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 156)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("待识别的健身房照片")
            }

            actionRow
            status
        }
        .card(filled: Theme.surface, padding: 16)
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                guard let image else { return }
                analyze(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                guard
                    let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                else {
                    vision.reportImageError()
                    return
                }
                analyze(image)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                showingCamera = true
            } label: {
                actionLabel("拍照", symbol: "camera.fill")
            }
            .disabled(
                !UIImagePickerController.isSourceTypeAvailable(.camera)
                    || vision.phase == .uploading || vision.phase == .saving
            )
            .accessibilityIdentifier("gym-camera-button")

            PhotosPicker(selection: $libraryItem, matching: .images) {
                actionLabel("从相册选择", symbol: "photo.on.rectangle")
            }
            .disabled(vision.phase == .uploading || vision.phase == .saving)
            .accessibilityIdentifier("gym-photo-library-button")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var status: some View {
        switch vision.phase {
        case .idle:
            Text("可跳过，之后也能在训练计划里补充。")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
        case .uploading:
            progress("正在识别器械…")
        case .saving:
            result
            progress("正在保存器械记忆…")
        case .ready:
            result
            Text("点击下方“继续”后，确认的器械会成为教练记忆。")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
        case .saved:
            result
            Label("器械已记住", systemImage: "checkmark.circle.fill")
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.success)
        case .failed(let message):
            result
            Label(message, systemImage: "exclamationmark.circle")
                .font(Theme.caption)
                .foregroundStyle(Theme.primary)
        }
    }

    @ViewBuilder
    private var result: some View {
        if let output = vision.result {
            Divider().overlay(Theme.border)

            Text(output.sceneSummary)
                .font(Theme.body)
                .foregroundStyle(Theme.mainText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(output.equipment) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(Theme.bodyStrong)
                        Text(item.visibleEvidence)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            ForEach(output.needsConfirmation, id: \.self) { item in
                Button {
                    vision.toggleAccepted(item)
                } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Image(
                            systemName: vision.accepted.contains(item)
                                ? "checkmark.square.fill" : "square"
                        )
                        .font(.system(size: 18))
                        .foregroundStyle(
                            vision.accepted.contains(item) ? Theme.primary : Theme.secondaryText)
                        Text(item)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.mainText)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .disabled(vision.phase == .saving || vision.phase == .saved)
            }

            if output.equipment.isEmpty && output.needsConfirmation.isEmpty {
                Text("没有认出可用器械，可以换个角度再拍一张。")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func progress(_ title: String) -> some View {
        HStack(spacing: 9) {
            ProgressView().tint(Theme.primary)
            Text(title).font(Theme.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    private func actionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(Theme.bodyStrong)
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.lightOrange)
            )
    }

    private func analyze(_ image: UIImage) {
        preview = image
        libraryItem = nil
        Task { await vision.recognize(image, goal: goal) }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate,
        UIImagePickerControllerDelegate
    {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
