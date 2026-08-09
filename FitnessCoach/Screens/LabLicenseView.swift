import SwiftUI

struct LabLicenseView: View {
    @Environment(WorkoutSession.self) private var session
    @Environment(LabProgress.self) private var progress
    @Binding var path: [Route]

    var body: some View {
        MobileAppShell {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 24)

                    Mascot(pose: .celebration, size: 180)

                    Text("GYM LICENSE")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.primary)

                    Text("LEVEL 1")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(Theme.mainText)

                    Text("你已经可以开始自己的第一次训练。")
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.mainText)

                    Text("你不需要记住所有答案。你已经知道如何观察、如何调整，以及什么时候应该停下来。")
                        .font(Theme.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !progress.personalPlan.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("你的第一份训练")
                                .font(Theme.cardTitle)
                            ForEach(progress.personalPlan, id: \.self) { name in
                                Label(name, systemImage: "checkmark.circle.fill")
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.mainText)
                            }
                        }
                        .card(filled: Theme.lightOrange)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 24)
            }
        } bottom: {
            BottomBar {
                VStack(spacing: 10) {
                    PrimaryButton(
                        title: session.canStartWorkout ? "开始我的训练" : "回到我的计划"
                    ) {
                        if session.canStartWorkout {
                            session.enterStrength()
                            path.replaceLast(with: .strength)
                        } else {
                            path.popToRoot()
                        }
                    }

                    Button("返回 Vance Lab") {
                        path.popToRoot()
                    }
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.primary)
                    .frame(height: 36)
                }
            }
        }
        .accessibilityIdentifier("lab-license")
    }
}
