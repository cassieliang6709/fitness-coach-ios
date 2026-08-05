import SwiftData
import SwiftUI
import UIKit

/// /home — the app's root after onboarding.
///
/// Two capsule tabs over one page, not two separate screens: 「对话」is where
/// you talk to the coach before training, 「我的计划」is today's plan plus what
/// you have actually finished. The header and the tab bar stay put across the
/// switch so it reads as one place.
struct HomeView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    @State private var tab = HomeTab.chat

    var body: some View {
        MobileAppShell {
            PageHeader(title: greeting, subtitle: subtitle) {
                Mascot(pose: tab == .chat ? .listening : .idle, size: 42)
            }

            switch tab {
            case .chat:
                HomeChatTab(thread: session.daily)
            case .plan:
                HomePlanTab(path: $path)
            }
        } bottom: {
            HomeBottomBar(tab: $tab) {
                switch tab {
                case .chat:
                    HomeInputBar(thread: session.daily)
                case .plan:
                    PrimaryButton(title: "开始今天的训练") {
                        session.enterStrength()
                        path.append(.strength)
                    }
                }
            }
        }
        .onAppear { session.daily.startIfNeeded() }
        .sheet(
            item: locationPickerBinding,
            onDismiss: {
                // A swipe-down cancels without persisting; the equipment photo
                // is already saved, only the location is skipped.
                if session.daily.pendingLocationSnapshot != nil {
                    session.daily.dismissLocationPicker()
                }
            }
        ) { snapshot in
            GymLocationPicker(
                snapshot: snapshot,
                onConfirm: { session.daily.confirmLocation($0) },
                onDismiss: { session.daily.dismissLocationPicker() }
            )
        }
    }

    /// Read-only presentation binding that routes dismissal through the thread,
    /// keeping the location state encapsulated on the coach thread.
    private var locationPickerBinding: Binding<GymLocationSnapshot?> {
        Binding(
            get: { session.daily.pendingLocationSnapshot },
            set: { newValue in
                if newValue == nil {
                    session.daily.dismissLocationPicker()
                }
            }
        )
    }

    // MARK: - Copy

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        default: return "晚上好"
        }
    }

    private var subtitle: String {
        tab == .chat ? "今天想练点什么？说一句就行。" : "今天的安排和你的记录"
    }
}

// MARK: - Bottom

/// The page's action plus the floating tab capsule. Written here rather than
/// reusing `BottomBar` because the tab bar has to float below the action.
private struct HomeBottomBar<Action: View>: View {
    @Binding var tab: HomeTab
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.border)

            action
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 12)

            CapsuleTabBar(selection: $tab)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        .background(Theme.background)
    }
}

// MARK: - Chat tab

/// The coach, before training. Same thread component as the coaching pages, so
/// the conversation looks identical wherever it happens.
private struct HomeChatTab: View {
    @Bindable var thread: CoachThread

    var body: some View {
        VStack(spacing: 0) {
            ChatThread(messages: thread.messages, isTyping: thread.isTyping)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            SuggestionRow(suggestions: thread.remainingSuggestions) { text in
                thread.send(text: text)
            }
        }
    }
}

/// Tappable openers. They disappear as they're used, so the row shrinks to
/// nothing instead of nagging with the same three chips forever.
private struct SuggestionRow: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onTap(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.mainText)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(
                                    Capsule(style: .continuous).fill(Theme.lightOrange)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
            .animation(.easeInOut(duration: 0.2), value: suggestions)
        }
    }
}

/// Compact input for the home tab. Deliberately not `WorkoutInputBar` — there
/// is no session to end here, and the big gym-sized mic would crowd out the
/// tab bar.
private struct HomeInputBar: View {
    @Bindable var thread: CoachThread

    @State private var draft = ""
    @State private var isShowingCamera = false
    @State private var cameraUnavailable = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 6) {
            if thread.isVisionRecognizing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("正在识别器械…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("和教练说点什么…", text: $draft)
                        .font(Theme.body)
                        .focused($focused)
                        .submitLabel(.send)
                        .onSubmit(submit)

                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(canSend ? Theme.primary : Theme.primary.opacity(0.35))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                }
                .padding(.horizontal, 12)
                .frame(height: Theme.tapTarget)
                .background(Capsule(style: .continuous).fill(Theme.surface))
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.border, lineWidth: 1))

                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        isShowingCamera = true
                    } else {
                        cameraUnavailable = true
                    }
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: Theme.tapTarget, height: Theme.tapTarget)
                        .background(Circle().fill(Theme.lightOrange))
                }
                .buttonStyle(.plain)
                .disabled(thread.isVisionRecognizing || thread.isBusy)
                .accessibilityLabel("拍摄器械图")

                IconButton(
                    symbol: thread.voiceState == .idle ? "mic.fill" : "stop.fill",
                    tint: thread.voiceState == .idle ? Theme.primary : .white,
                    background: thread.voiceState == .idle ? Theme.lightOrange : Theme.primary
                ) {
                    if thread.voiceState == .idle {
                        thread.beginVoiceTurn()
                    } else {
                        thread.cancelVoiceTurn()
                    }
                }
                .accessibilityLabel(thread.voiceState == .idle ? "开始语音" : "取消语音")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: thread.voiceState)
        .animation(.easeInOut(duration: 0.2), value: thread.isVisionRecognizing)
        .sheet(isPresented: $isShowingCamera) {
            GymCameraPicker(
                onCapture: capture,
                onDismiss: { isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
        .alert("无法使用相机", isPresented: $cameraUnavailable) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请在真机上允许相机权限后再拍摄器械。")
        }
    }

    private func capture(_ image: UIImage) {
        Task {
            let captureStartedAt = Date()
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
            let captureTiming = GymVisionCaptureTiming(
                startedAt: captureStartedAt,
                jpegElapsedMilliseconds: Int(Date().timeIntervalSince(captureStartedAt) * 1_000),
                imageBytes: jpeg.count
            )
            // Start the foreground location convergence at the same time as the
            // Kimi upload. The image path never needs location data, so it must
            // not wait for GPS or POI resolution before it starts.
            let locationTask = Task {
                let startedAt = Date()
                let snapshot = await GymLocationService.shared.currentLocation()
                return GymLocationLookup(
                    snapshot: snapshot,
                    elapsedMilliseconds: Int(Date().timeIntervalSince(startedAt) * 1_000)
                )
            }
            await thread.recognizeGymEquipment(
                imageData: jpeg,
                mimeType: "image/jpeg",
                locationTask: locationTask,
                captureTiming: captureTiming
            )
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !thread.isBusy
    }

    private func submit() {
        guard canSend else { return }
        thread.send(text: draft)
        draft = ""
    }
}

// MARK: - Native camera and foreground location

/// `UIImagePickerController` is used deliberately: unlike a photo picker it
/// invokes the device camera and its system permission sheet directly.
private struct GymCameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onDismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                picker.dismiss(animated: true, completion: onDismiss)
                return
            }
            picker.dismiss(animated: true) {
                self.onDismiss()
                self.onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion: onDismiss)
        }
    }
}

// MARK: - Plan tab

/// Today's plan and the user's own record. Every number is read back from
/// storage — a new account sees zeros, not a fake streak.
private struct HomePlanTab: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store
    @Binding var path: [Route]

    @Query(
        filter: #Predicate<MemoryRecord> { $0.active },
        sort: \MemoryRecord.createdAt
    )
    private var memories: [MemoryRecord]

    @Query(
        filter: #Predicate<SessionRecord> { $0.endedAt != nil },
        sort: \SessionRecord.startedAt,
        order: .reverse
    )
    private var sessions: [SessionRecord]

    @State private var isShowingMemoryLibrary = false

    private var stats: TrainingStats {
        TrainingStats(sessions: sessions, weeklyTarget: store?.weeklyTarget ?? 4)
    }

    var body: some View {
        @Bindable var session = session

        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                todayCard

                WeekStripe(stats: stats)

                MetricRow(metrics: stats.tiles)

                memorySection

                if !sessions.isEmpty {
                    historySection
                }

                AIStyleSelector(selection: $session.aiStyle)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 16)
        }
    }

    // MARK: Sections

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PlanThumbnail(symbol: session.plan.symbol, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("今天")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Text(session.plan.title)
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.mainText)
                    Text(session.plan.tags.joined(separator: " · "))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 8)
            }

            VStack(spacing: 8) {
                ForEach(session.plan.sections) { section in
                    HStack(spacing: 8) {
                        Image(systemName: section.kind.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 18)

                        Text(section.kind.title)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)

                        Spacer(minLength: 8)

                        Text(section.duration)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 8) {
                GhostButton(title: "查看完整计划", symbol: "list.bullet") {
                    path.append(.legDay)
                }

                GhostButton(title: "换个计划", symbol: "square.grid.2x2", tint: Theme.secondaryText) {
                    path.append(.plans)
                }
            }
        }
        .card(selected: true)
    }

    private var memorySection: some View {
        let equipmentMemories = memories.filter { $0.category == .equipment }
        let otherMemories = memories.filter { $0.category != .equipment }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "AI 记住的事", detail: "\(memories.count) 条")
                Spacer()
                Button("编辑记忆") { isShowingMemoryLibrary = true }
                    .font(Theme.caption)
                    .foregroundStyle(Theme.primary)
                    .accessibilityLabel("编辑记忆")
            }

            if memories.isEmpty {
                Text("还没有记录。训练时说一句，我就记住了。")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                if !equipmentMemories.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(equipmentMemories) { memory in
                            EquipmentLocationMemoryRow(memory: memory.asMemory)
                        }
                    }
                }
                if !otherMemories.isEmpty {
                    MemoryChipRow(memories: otherMemories.map(\.asMemory))
                }
            }
        }
        .sheet(isPresented: $isShowingMemoryLibrary) {
            MemoryLibrarySheet()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "最近训练", detail: stats.weeklyHeadline)

            VStack(spacing: 8) {
                ForEach(sessions.prefix(3)) { record in
                    HistoryRow(record: record)
                }
            }
        }
    }
}

/// A whole location and its confirmed equipment live in one editable memory,
/// so the list never fragments a single gym into multiple device chips.
private struct EquipmentLocationMemoryRow: View {
    let memory: WorkoutMemory

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 20, alignment: .leading)
            Text(memory.text)
                .font(Theme.body)
                .foregroundStyle(Theme.mainText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// Quiet section label used down the plan tab.
private struct SectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.mainText)

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

private struct HistoryRow: View {
    let record: SessionRecord

    private static let dayFormat: Date.FormatStyle =
        .dateTime.month(.defaultDigits).day(.defaultDigits)

    var body: some View {
        HStack(spacing: 10) {
            Image(
                systemName: record.completionPercent >= 100
                    ? "checkmark.circle.fill" : "circle.lefthalf.filled"
            )
            .font(.system(size: 15))
            .foregroundStyle(record.completionPercent >= 100 ? Theme.success : Theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.planTitle)
                    .font(Theme.body)
                    .foregroundStyle(Theme.mainText)
                Text(record.startedAt.formatted(Self.dayFormat))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 8)

            Text("\(record.durationMinutes) 分钟 · \(record.completionPercent)%")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
        )
    }
}
