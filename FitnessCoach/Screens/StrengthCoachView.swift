import SwiftUI

/// /workout/strength
struct StrengthCoachView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    @State private var confirmEnd = false
    @State private var realtime = RealtimeSession()
    @State private var realtimeDraft = ""

    @ViewBuilder
    var body: some View {
        if session.exercises.isEmpty {
            planLoadingView
        } else {
            workoutView
        }
    }

    /// A DEBUG deep link can render this destination before the asynchronous
    /// plan sync finishes. Keep that transient state out of `currentExercise`,
    /// whose progress APIs intentionally require a real exercise.
    private var planLoadingView: some View {
        MobileAppShell {
            PageHeader(
                title: "力量陪练",
                style: .navBar,
                onBack: { path.removeLast() }
            )

            Spacer()
            if session.isPlanLoading {
                ProgressView("正在加载训练计划…")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ContentUnavailableView(
                    "还没有可用计划",
                    systemImage: "list.bullet.clipboard",
                    description: Text("先回到我的计划生成今天的训练，再进入力量陪练。")
                )
            }
            Spacer()
        }
    }

    private var workoutView: some View {
        MobileAppShell {
            PageHeader(
                title: "力量陪练",
                style: .navBar,
                onBack: { path.removeLast() }
            )

            // Sticky: sits outside the scroll view, so it never moves.
            CurrentTaskCard(
                title: session.currentExerciseName,
                metrics: session.strengthMetrics,
                progressLabel: session.setProgressLabel,
                secondaryLabel: session.exerciseProgressLabel,
                venue: session.trainingVenue,
                exerciseID: session.currentExercise.id,
                pose: session.isResting ? .drink : .dumbbell
            ) {
                accessory
            }

            if session.usesDemoData {
                ChatThread(
                    messages: session.strength.messages,
                    isTyping: session.strength.isTyping
                )
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
            } else {
                RealtimeCoachPanel(session: realtime)
            }
        } bottom: {
            if session.phase == .strengthComplete {
                BottomBar {
                    PrimaryButton(title: "力量部分完成，进入有氧") {
                        session.enterCardio()
                        path.replaceLast(with: .cardio)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if session.usesDemoData {
                WorkoutInputBar(thread: session.strength) {
                    confirmEnd = true
                }
            } else {
                BottomBar {
                    VStack(spacing: 10) {
                        RealtimeCoachControls(session: realtime, draft: $realtimeDraft)
                        Button("结束训练") { confirmEnd = true }
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .onAppear {
            session.enterStrength()
            guard !session.usesDemoData else { return }
            configureRealtime()
            realtime.connect()
        }
        .onChange(of: session.realtimeCoachContext) {
            guard !session.usesDemoData else { return }
            configureRealtime()
        }
        .onDisappear { realtime.disconnect() }
        .confirmationDialog("结束本次训练？", isPresented: $confirmEnd, titleVisibility: .visible) {
            // Sets are already logged, so ending early goes to the review and
            // reports the partial session rather than discarding it.
            Button("结束并查看复盘") {
                session.enterReview()
                path.replaceLast(with: .review)
            }
            Button("继续训练", role: .cancel) {}
        }
    }

    private func configureRealtime() {
        realtime.configure(
            style: session.aiStyle,
            state: session.realtimeCoachContext,
            memories: session.realtimeMemories
        )
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
                SetProgressDots(
                    total: session.currentExercise.sets,
                    completed: session.completedSetsForCurrentExercise
                )

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
