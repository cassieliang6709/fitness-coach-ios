import SwiftUI

/// Gym-photo-driven card picker: swipe up to keep, down to replace, then hand
/// the accepted sequence to the existing coached workout state machine.
struct ExerciseDrawTab: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(\.workoutStore) private var store
    @Binding var path: [Route]

    @State private var vision = GymVision(userID: InstallIdentity.current)
    @State private var showsScanner = false
    @State private var selectedIDs: [String] = []
    @State private var candidateID: String?
    @State private var cardOffset: CGFloat = 0

    private var selected: [ExerciseDefinition] {
        selectedIDs.compactMap(ExerciseCatalog.exercise)
    }

    private var candidate: ExerciseDefinition? {
        candidateID.flatMap(ExerciseCatalog.exercise)
    }

    private var profile: UserProfile {
        store?.profile() ?? UserProfile()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                photoEntry

                if showsScanner, let vision {
                    GymPhotoScanner(vision: vision, goal: profile.goal.label)

                    if vision.result != nil {
                        Button("按识别到的器械重新抽") {
                            selectedIDs = []
                            dealNext()
                        }
                        .font(Theme.bodyStrong)
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
                        .background(Capsule().fill(Theme.lightOrange))
                    }
                }

                selectionSummary

                if let candidate {
                    DrawCandidateCard(exercise: candidate)
                        .offset(y: cardOffset)
                        .gesture(
                            DragGesture(minimumDistance: 18)
                                .onChanged { value in
                                    cardOffset = value.translation.height * 0.35
                                }
                                .onEnded { value in
                                    if value.translation.height < -60 {
                                        accept(candidate)
                                    } else if value.translation.height > 60 {
                                        replaceCandidate()
                                    } else {
                                        withAnimation(.spring(response: 0.25)) { cardOffset = 0 }
                                    }
                                }
                        )
                        .accessibilityIdentifier("draw-candidate-\(candidate.id)")

                    decisionRow(candidate)
                }

                if selected.count >= 3 {
                    PrimaryButton(title: "用这 \(selected.count) 个动作开始") {
                        guard session.configureDrawnWorkout(selected) else { return }
                        session.enterStrength()
                        path.append(.strength)
                    }
                    .accessibilityIdentifier("start-drawn-workout")
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if candidateID == nil { dealNext() }
        }
    }

    private var photoEntry: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showsScanner.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.lightOrange))

                VStack(alignment: .leading, spacing: 3) {
                    Text("先拍一下健身房")
                        .font(Theme.bodyStrong)
                        .foregroundStyle(Theme.mainText)
                    Text(vision == nil ? "识别服务未配置，也可以直接抽动作" : "识别器械后，只抽现场能做的动作")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()
                Image(systemName: showsScanner ? "chevron.up" : "chevron.down")
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .card(filled: Theme.surface, padding: 12)
        .disabled(vision == nil)
        .accessibilityIdentifier("draw-photo-entry")
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今天的流程")
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.mainText)
                Spacer()
                Text("\(selected.count) / 3–6")
                    .font(Theme.caption)
                    .foregroundStyle(selected.count >= 3 ? Theme.success : Theme.secondaryText)
                    .monospacedDigit()
            }

            if selected.isEmpty {
                Text("上滑加入 · 下滑换一个")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selected.enumerated()), id: \.element.id) { index, exercise in
                            HStack(spacing: 5) {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                Text(exercise.name)
                                    .font(Theme.caption)
                                    .foregroundStyle(Theme.mainText)
                                Button {
                                    selectedIDs.removeAll { $0 == exercise.id }
                                    dealNext()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Capsule().fill(Theme.lightOrange))
                        }
                    }
                }
            }
        }
    }

    private func decisionRow(_ exercise: ExerciseDefinition) -> some View {
        HStack(spacing: 10) {
            Button {
                replaceCandidate()
            } label: {
                Label("下滑换掉", systemImage: "arrow.down")
                    .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText)
            .background(Capsule().fill(Theme.surface))

            Button {
                accept(exercise)
            } label: {
                Label("上滑加入", systemImage: "arrow.up")
                    .frame(maxWidth: .infinity, minHeight: Theme.tapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Capsule().fill(Theme.primary))
            .disabled(selected.count >= 6)
        }
    }

    private var pool: [ExerciseDefinition] {
        let safe = ExerciseCatalog.available(for: profile)
        let detected = detectedEquipment
        guard !detected.isEmpty else { return safe }
        return safe.filter { exercise in
            !exercise.equipment.isDisjoint(with: detected)
                || exercise.equipment.contains(.bodyweight)
                || exercise.equipment.contains(.mat)
        }
    }

    private var detectedEquipment: Set<ExerciseEquipment> {
        guard let vision else { return [] }
        return vision.confirmedEquipment.reduce(into: Set<ExerciseEquipment>()) { result, raw in
            let name = raw.lowercased()
            if name.contains("哑铃") || name.contains("dumbbell") { result.insert(.dumbbell) }
            if name.contains("壶铃") || name.contains("kettlebell") { result.insert(.kettlebell) }
            if name.contains("杠铃") || name.contains("barbell") { result.insert(.barbell) }
            if name.contains("龙门") || name.contains("绳索") || name.contains("cable") { result.insert(.cable) }
            if name.contains("单杠") || name.contains("pull-up") { result.insert(.pullUpBar) }
            if name.contains("训练凳") || name.contains("bench") { result.insert(.bench) }
            if name.contains("弹力带") || name.contains("band") { result.insert(.resistanceBand) }
            if name.contains("跑步机") || name.contains("单车") || name.contains("椭圆") || name.contains("划船机") || name.contains("cardio") { result.insert(.cardioMachine) }
            if name.contains("战绳") || name.contains("battle rope") { result.insert(.battleRope) }
            if name.contains("器械") || name.contains("machine") { result.insert(.machine) }
        }
    }

    private func accept(_ exercise: ExerciseDefinition) {
        guard selected.count < 6 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedIDs.append(exercise.id)
            cardOffset = -120
        }
        dealNext()
    }

    private func replaceCandidate() {
        withAnimation(.easeInOut(duration: 0.18)) { cardOffset = 120 }
        dealNext()
    }

    private func dealNext() {
        let desired: ExerciseCategory? = switch selected.count {
        case 0: .strength
        case 1: .core
        case 2: .cardio
        case 3: .mobility
        default: nil
        }
        let unused = pool.filter { !selectedIDs.contains($0.id) && $0.id != candidateID }
        let matching = desired.map { category in unused.filter { $0.category == category } } ?? unused
        candidateID = (matching.isEmpty ? unused : matching).randomElement()?.id
        cardOffset = 0
    }
}

private struct DrawCandidateCard: View {
    let exercise: ExerciseDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.category.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(Theme.lightOrange))
                Spacer()
                Text(exercise.level.label)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            ExerciseArtwork(exercise: exercise, size: 172)
                .frame(maxWidth: .infinity)

            Text(exercise.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.mainText)
            Text("\(exercise.muscleLabel) · \(exercise.equipmentLabel)")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)

            ForEach(exercise.coachingTips.prefix(2), id: \.self) { tip in
                Label(tip, systemImage: "checkmark.circle.fill")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.mainText)
            }
        }
        .card(selected: true, padding: 14)
    }
}
