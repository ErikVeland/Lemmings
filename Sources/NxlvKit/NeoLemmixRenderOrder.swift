public enum NeoLemmixRenderOrder {
    private static let permanentTraits: Set<NeoLemmixTrait> = [
        .shimmier, .slider, .climber, .swimmer, .floater, .glider, .disarmer,
    ]

    /// CE draws low-priority lemmings first so higher-priority lemmings remain visible.
    public static func priority(
        action: NeoLemmixAction,
        traits: Set<NeoLemmixTrait>,
        isSelected: Bool = false,
        isHighlighted: Bool = false
    ) -> Int {
        var value = 0
        if isSelected { value += 128 }
        if action != .exiting { value += 64 }
        if isHighlighted { value += 32 }
        if !traits.contains(.neutral) || traits.contains(.zombie) { value += 8 }
        if !traits.contains(.zombie) { value += 16 }
        if !traits.isDisjoint(with: permanentTraits) { value += 4 }
        return value
    }

    /// Reproduces the unstable quicksort used by CE's Delphi `TList.SortList`.
    /// Equal-priority actors must be permuted the same way for overlapping
    /// partially transparent sprite pixels to composite identically.
    public static func sorted<Element>(
        _ elements: [Element],
        priority: (Element) -> Int
    ) -> [Element] {
        guard elements.count > 1 else { return elements }
        var result = elements

        func quickSort(_ left: Int, _ right: Int) {
            // Delphi leaves partitions of four or fewer entries for its final
            // insertion pass. This detail controls the order of equal items.
            guard right - left > 3 else { return }
            var lower = left
            var upper = right
            let pivot = priority(result[(left + right) >> 1])
            repeat {
                while priority(result[lower]) < pivot { lower += 1 }
                while priority(result[upper]) > pivot { upper -= 1 }
                if lower <= upper {
                    result.swapAt(lower, upper)
                    lower += 1
                    upper -= 1
                }
            } while lower <= upper
            if left < upper { quickSort(left, upper) }
            if lower < right { quickSort(lower, right) }
        }

        quickSort(0, result.count - 1)
        for index in 1..<result.count {
            var insertion = index
            while insertion > 0,
                  priority(result[insertion]) < priority(result[insertion - 1]) {
                result.swapAt(insertion, insertion - 1)
                insertion -= 1
            }
        }
        return result
    }

    public static func sorted(
        _ lemmings: [NeoLemmixLemming],
        selectedID: Int? = nil,
        highlightedID: Int? = nil
    ) -> [NeoLemmixLemming] {
        sorted(lemmings) { lemming in
            priority(
                action: lemming.renderOrderActionBeforeRemoval ?? lemming.action,
                traits: lemming.traits,
                isSelected: lemming.id == selectedID,
                isHighlighted: lemming.id == highlightedID
            )
        }
    }
}
