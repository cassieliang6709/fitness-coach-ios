import SwiftData
import SwiftUI

/// /plans
struct PlanLibraryView: View {
    @Environment(WorkoutSession.self) private var session
    @Binding var path: [Route]

    /// Memory chips come from storage now — they accumulate across sessions.
    @Query(
        filter: #Predicate<MemoryRecord> { $0.active },
        sort: \MemoryRecord.createdAt
    )
    private var memories: [MemoryRecord]

    var body: some View {
        MobileAppShell {
            PageHeader(
                title: "训练计划库",
                style: .navBar,
                onBack: { path.removeLast() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    MemoryChipRow(memories: memories.map(\.asMemory))
                        .padding(.bottom, 2)

                    ExerciseLibraryTeaser {
                        path.append(.exerciseLibrary)
                    }

                    if session.canStartWorkout {
                        PlanCard(plan: session.plan, featured: true, selected: true)
                        if !session.usesLivePlanService {
                            ForEach(MockData.otherPlans) { plan in
                                PlanCard(plan: plan)
                            }
                        }
                    } else {
                        MemoryNoteCard(
                            title: "还没有可用计划",
                            message: session.planError ?? "根据你的目标和身体状态生成后，会显示在这里。"
                        )
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 16)
            }
        } bottom: {
            BottomBar {
                if session.usesLivePlanService {
                    PrimaryButton(
                        title: session.isPlanLoading
                            ? "正在生成…"
                            : (session.canStartWorkout ? "让 AI 换一份" : "生成计划"),
                        enabled: !session.isPlanLoading
                    ) {
                        Task { await session.regeneratePlan() }
                    }
                } else {
                    PrimaryButton(
                        title: session.canStartWorkout ? "查看计划" : "教练服务未配置",
                        enabled: session.canStartWorkout
                    ) {
                        if session.canStartWorkout {
                            path.append(.legDay)
                        }
                    }
                }
            }
        }
    }
}

/// Wraps so chips stay on one line and never cause horizontal page scroll.
struct MemoryChipRow: View {
    let memories: [WorkoutMemory]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(memories) { memory in
                MemoryChip(memory: memory)
            }
        }
    }
}

/// Minimal wrapping layout — chips flow onto the next line instead of
/// overflowing the viewport.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [CGFloat] = [0]
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let current = rows[rows.count - 1]
            let candidate = current == 0 ? size.width : current + spacing + size.width
            if candidate > maxWidth, current > 0 {
                height += rowHeight + spacing
                rows.append(size.width)
                rowHeight = size.height
            } else {
                rows[rows.count - 1] = candidate
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight
        return CGSize(width: maxWidth == .infinity ? rows.max() ?? 0 : maxWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
