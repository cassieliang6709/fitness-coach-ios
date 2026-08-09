import SwiftUI

struct LabHomeView: View {
    @Environment(LabProgress.self) private var progress
    @Binding var path: [Route]

    private var lesson: LabLesson {
        LabCourse.lesson(day: progress.currentDay)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                LabProgressStrip(
                    completedDays: progress.completedDays,
                    currentDay: progress.currentDay
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.code)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(Theme.primary)

                    Text(lesson.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.mainText)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(
                        "Day \(lesson.day) of 7",
                        systemImage: "calendar"
                    )
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                }

                hero

                VStack(alignment: .leading, spacing: 10) {
                    LabNotebookLabel(text: lesson.day == 2 ? "今天的假设" : "CURRENT STUDY")

                    Text(lesson.subtitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.mainText)

                    Text(
                        progress.isCourseComplete
                            ? "七个 Lab 已完成。你的第一份训练计划已经准备好了。"
                            : "完成真实观察，才会点亮今天的研究区域。"
                    )
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .background(Theme.labBackground)
        .accessibilityIdentifier("lab-home")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Mascot(pose: .idle, size: 44)
            Text("Vance Lab")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Theme.mainText)

            Spacer()

            Text("已掌握 \(progress.masteredCount) / 7")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var hero: some View {
        if lesson.day == 2 || progress.isCourseComplete {
            LabBodyMap(compact: true)
                .frame(height: 286)
        } else if let exercise = heroExercise {
            ExerciseArtwork(exercise: exercise, size: 230)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
        } else {
            Mascot(pose: .point, size: 210)
                .frame(maxWidth: .infinity)
                .frame(height: 260)
        }
    }

    private var heroExercise: ExerciseDefinition? {
        let id: String
        switch lesson.day {
        case 1: id = "machine-chest-press"
        case 3: id = "lat-pulldown"
        case 4: id = "leg-press"
        case 5: id = "seated-cable-row"
        default: return nil
        }
        return ExerciseCatalog.exercise(id: id)
    }
}
