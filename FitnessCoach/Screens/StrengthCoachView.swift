import SwiftUI

/// /workout/strength
struct StrengthCoachView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    @State private var confirmEnd = false

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "力量陪练",
                style: .navBar,
                onBack: { path.removeLast() }
            )

            // Sticky: sits outside the scroll view, so it never moves.
            CurrentTaskCard(
                title: session.coachedExercise.name,
                metrics: session.strengthMetrics,
                progressLabel: session.setProgressLabel,
                venue: MockData.strengthVenue,
                pose: session.isResting ? .drink : .dumbbell
            ) {
                accessory
            }

            ChatThread(
                messages: session.strength.messages,
                isTyping: session.strength.isTyping
            )
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
        } bottom: {
            if session.phase == .strengthComplete {
                BottomBar {
                    PrimaryButton(title: "力量部分完成，进入有氧") {
                        session.enterCardio()
                        path.replaceLast(with: .cardio)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                WorkoutInputBar(thread: session.strength) {
                    confirmEnd = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .onAppear { session.enterStrength() }
        .confirmationDialog("结束本次训练？", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("结束训练", role: .destructive) {
                session.reset()
                path.popToRoot()
            }
            Button("继续训练", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var accessory: some View {
        if session.isResting {
            RestTimer(remaining: session.restRemaining) {
                session.skipRest()
            }
            .transition(.opacity)
        } else {
            HStack(spacing: 10) {
                SetProgressDots(total: session.totalSets, completed: session.completedSets)

                Spacer(minLength: 8)

                if session.phase == .strengthActive {
                    GhostButton(title: "完成这组", symbol: "checkmark") {
                        session.completeCurrentSet()
                    }
                } else {
                    Label("力量完成", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.success)
                }
            }
        }
    }
}
