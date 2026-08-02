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
            PageHeader(title: "训练计划库")

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    MemoryChipRow(memories: memories.map(\.asMemory))
                        .padding(.bottom, 2)

                    PlanCard(plan: session.plan, featured: true, selected: true)

                    ForEach(MockData.otherPlans) { plan in
                        PlanCard(plan: plan)
                    }
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 16)
            }
        } bottom: {
            BottomBar {
                PrimaryButton(title: "查看计划") {
                    path.append(.legDay)
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

/// The editable source of truth behind the compact chips in “我的计划”.
/// Disabling is used instead of hard-deleting so a Kimi or manual correction
/// does not silently erase the user's history.
struct MemoryLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.workoutStore) private var store

    @Query(
        filter: #Predicate<MemoryRecord> { $0.active },
        sort: \MemoryRecord.updatedAt,
        order: .reverse
    )
    private var memories: [MemoryRecord]

    @State private var selectedID: String?
    @State private var draft = ""
    @State private var category: MemoryCategory = .preference
    @State private var isShowingEditor = false

    var body: some View {
        NavigationStack {
            List {
                if memories.isEmpty {
                    ContentUnavailableView("还没有记忆", systemImage: "brain.head.profile")
                } else {
                    ForEach(memories) { memory in
                        Button {
                            selectedID = memory.id
                            draft = memory.text
                            category = memory.category
                            isShowingEditor = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: memory.category.symbol)
                                    .foregroundStyle(Theme.primary)
                                    .frame(width: 20)
                                Text(memory.text)
                                    .foregroundStyle(Theme.mainText)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("记忆库")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedID = nil
                        draft = ""
                        category = .preference
                        isShowingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加记忆")
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                MemoryEditorSheet(
                    title: selectedID == nil ? "添加记忆" : "修改记忆",
                    draft: $draft,
                    category: $category,
                    canDisable: selectedID != nil,
                    onSave: save,
                    onDisable: disable
                )
            }
        }
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let selectedID {
            store?.updateMemory(id: selectedID, category: category, text: text)
        } else {
            store?.upsertMemory(
                id: "manual-\(UUID().uuidString)",
                category: category,
                text: text,
                sourceSessionID: nil
            )
        }
        isShowingEditor = false
    }

    private func disable() {
        guard let selectedID else { return }
        store?.deactivateMemory(id: selectedID)
        isShowingEditor = false
    }
}

private struct MemoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var draft: String
    @Binding var category: MemoryCategory
    let canDisable: Bool
    let onSave: () -> Void
    let onDisable: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $category) {
                    ForEach(MemoryCategory.allCases, id: \.self) { category in
                        Label(category.label, systemImage: category.symbol).tag(category)
                    }
                }
                TextField("例如：右膝不适，避免跳跃", text: $draft, axis: .vertical)
                    .lineLimit(2...5)
                if canDisable {
                    Button("不再使用这条记忆", role: .destructive) {
                        onDisable()
                        dismiss()
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
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
