import SwiftUI

/// /workout/cardio
struct CardioCoachView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    @State private var confirmEnd = false
    @State private var realtime = RealtimeSession()
    @State private var realtimeDraft = ""

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "有氧陪练",
                style: .navBar,
                onBack: { path.removeLast() }
            )

            // Same sticky task card component as the strength page.
            CurrentTaskCard(
                title: session.cardioName,
                metrics: session.cardioPrescription,
                progressLabel: session.cardioProgressLabel,
                progress: session.cardioProgress,
                pose: session.phase == .cardioComplete ? .thumbsUp : .jogging
            ) {
                if session.phase != .cardioComplete {
                    HStack {
                        Spacer(minLength: 0)
                        GhostButton(title: "完成有氧", symbol: "flag.checkered") {
                            session.completeCardio()
                        }
                    }
                }
            }

            if session.usesDemoData {
                ChatThread(
                    messages: session.cardio.messages,
                    isTyping: session.cardio.isTyping
                )
                .frame(maxHeight: .infinity)
                .layoutPriority(1)
            } else {
                RealtimeCoachPanel(session: realtime)
            }
        } bottom: {
            if session.phase == .cardioComplete {
                BottomBar {
                    PrimaryButton(title: "有氧完成，查看复盘") {
                        session.enterReview()
                        path.replaceLast(with: .review)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if session.usesDemoData {
                WorkoutInputBar(thread: session.cardio) {
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
            session.enterCardio()
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
}
