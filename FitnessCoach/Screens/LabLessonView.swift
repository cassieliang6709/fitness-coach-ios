import SwiftUI

struct LabLessonView: View {
    @Environment(LabProgress.self) private var progress
    let day: Int
    @Binding var path: [Route]

    @State private var stepIndex = 0
    @State private var selectedChoice: String?

    private var lesson: LabLesson { LabCourse.lesson(day: day) }
    private var step: LabStep { lesson.steps[stepIndex] }

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: lesson.code,
                style: .navBar,
                onBack: { path.removeLast() }
            ) {
                Text("\(stepIndex + 1) / \(lesson.steps.count)")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }

            ProgressView(value: Double(stepIndex + 1), total: Double(lesson.steps.count))
                .tint(Theme.primary)
                .padding(.horizontal, Theme.pagePadding)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stepLabel

                    Text(step.title)
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(Theme.mainText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.body)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    artwork
                    bullets
                    choices
                    feedback

                    if step.kind == .tryIt || step.kind == .apply {
                        LabSafetyNote()
                    }

                    if let note = step.note {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "scribble.variable")
                                .foregroundStyle(Theme.labBlue)
                            Text(note)
                                .font(Theme.body)
                                .foregroundStyle(Theme.mainText)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        } bottom: {
            BottomBar {
                PrimaryButton(
                    title: stepIndex == lesson.steps.count - 1 ? "完成今天的 Lab" : "继续",
                    enabled: !step.needsChoice || selectedChoice != nil,
                    action: advance
                )
                .accessibilityIdentifier("lab-next")
            }
        }
        .background(Theme.labBackground)
        .onAppear(perform: restore)
        .onChange(of: stepIndex) { _, _ in restoreChoice() }
        .accessibilityIdentifier("lab-lesson-\(day)")
    }

    private var stepLabel: some View {
        Group {
            if step.kind == .predict || step.kind == .observe {
                LabNotebookLabel(text: step.kind.label)
            } else {
                Text(step.kind.label)
                    .font(.system(size: 13, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(step.kind == .explain ? Theme.labBlue : Theme.primary)
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if day == 2 && step.id == "human" {
            LabBodyMap(compact: true)
                .frame(height: 300)
        } else if let id = step.exerciseID,
            let exercise = ExerciseCatalog.exercise(id: id)
        {
            ExerciseArtwork(exercise: exercise, size: 220)
                .frame(maxWidth: .infinity)
                .frame(height: 236)
        } else if step.kind == .learn || step.kind == .explain {
            Mascot(pose: .point, size: 112)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var bullets: some View {
        if !step.bullets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(step.bullets.enumerated()), id: \.offset) { index, bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.lightOrange))

                        Text(bullet)
                            .font(Theme.body)
                            .foregroundStyle(Theme.mainText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var choices: some View {
        if !step.choices.isEmpty {
            VStack(spacing: 10) {
                ForEach(step.choices) { choice in
                    LabChoiceButton(
                        title: choice.title,
                        isSelected: selectedChoice == choice.id
                    ) {
                        selectedChoice = choice.id
                        progress.save(answer: choice.id, lessonDay: day, stepID: step.id)
                    }
                    .accessibilityIdentifier("lab-choice-\(choice.id)")
                }
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let selectedChoice,
            let choice = step.choices.first(where: { $0.id == selectedChoice }),
            let message = choice.feedback
        {
            HStack(alignment: .top, spacing: 10) {
                Mascot(pose: .listening, size: 38)
                Text(message)
                    .font(Theme.body)
                    .foregroundStyle(Theme.mainText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.lightOrange)
            )
        }
    }

    private func restore() {
        stepIndex = min(progress.step(for: day), max(lesson.steps.count - 1, 0))
        restoreChoice()
    }

    private func restoreChoice() {
        selectedChoice = progress.answer(lessonDay: day, stepID: step.id)
    }

    private func advance() {
        if stepIndex < lesson.steps.count - 1 {
            stepIndex += 1
            progress.save(step: stepIndex, for: day)
        } else {
            progress.complete(day: day)
            path.removeLast()
        }
    }
}
