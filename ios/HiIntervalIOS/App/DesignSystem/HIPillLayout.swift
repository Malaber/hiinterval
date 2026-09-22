import SwiftUI

/// A flow layout for compact metadata that should remain readable at every Dynamic Type size.
struct HIPillLayout: Layout {
    var spacing: CGFloat = HITheme.Spacing.xSmall

    init(spacing: CGFloat = HITheme.Spacing.xSmall) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(for: subviews, availableWidth: availableWidth)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = rows(for: subviews, availableWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, availableWidth: CGFloat) -> [Row] {
        guard !subviews.isEmpty else { return [] }
        let constrainedWidth = max(0, availableWidth)
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let naturalSize = subview.sizeThatFits(
                ProposedViewSize(width: constrainedWidth, height: nil)
            )
            let size = CGSize(width: min(naturalSize.width, constrainedWidth), height: naturalSize.height)
            let neededWidth = current.items.isEmpty ? size.width : current.width + spacing + size.width

            if !current.items.isEmpty && neededWidth > constrainedWidth {
                rows.append(current)
                current = Row()
            }

            current.items.append(Item(subview: subview, size: size))
            current.width += current.items.count == 1 ? size.width : spacing + size.width
            current.height = max(current.height, size.height)
        }

        rows.append(current)
        return rows
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        var items: [Item] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}
