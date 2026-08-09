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

                    Text("这是你的第一版训练计划。")
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.mainText)

                    Text("接下来四周，用训练记录看看它是否适合你的时间、目标和恢复情况。动作可以换，忙的时候也可以直接使用短版本。")
                        .font(Theme.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !progress.weeklyPlan.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("你的一周")
                                .font(Theme.cardTitle)
                            ForEach(progress.weeklyPlan, id: \.self) { item in
                                Label(item, systemImage: "calendar.badge.checkmark")
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.mainText)
                            }
                        }
                        .card(filled: Theme.surface)
                    }

                    if !progress.personalPlan.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Workout A · Full Body")
                                .font(Theme.cardTitle)
                            ForEach(progress.personalPlan, id: \.self) { name in
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(name, systemImage: "checkmark.circle.fill")
                                        .font(Theme.bodyStrong)
                                        .foregroundStyle(Theme.mainText)
                                    Text("2 × 8–12 · 约 2–4 RIR")
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                        .padding(.leading, 28)
                                }
                            }
                        }
                        .card(filled: Theme.lightOrange)
                    }

                    Text("如果重量让动作提前失控，降低一档或减少次数。出现安全警讯时，停止对应活动。时间不足时先做前面的主要动作，不用加速赶完。")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
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
