import AppKit

struct KeyboardCommand {
    let keys: String
    let action: String
    let group: String
}

/// A searchable native table keeps the command reference usable with keyboard and VoiceOver.
@MainActor final class KeyboardCommandsView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let commands: [KeyboardCommand]
    private(set) var filtered: [KeyboardCommand] = []
    let search = GameSearchField()
    let category = GamePopUpButton()
    private let table = NSTableView()
    private let count = GameLabel(labelWithString: "")

    init(commands: [KeyboardCommand], modern: Bool) {
        self.commands = commands
        super.init(frame: NSRect(x: 0, y: 0, width: 780, height: 450))
        let intro = GameLabel(wrappingLabelWithString: "Esc  •  Save and return to the main menu     Space  •  Pause     F  •  Fast-forward\n" + (modern ? "Number keys select skills by position. Letter bindings follow the current level." : "Modern shortcuts are off. Use number keys for skills; enable modern controls in Settings."))
        search.placeholderString = "Find a key or command, e.g. rewind, Shift, builder"
        search.setAccessibilityLabel("Search keyboard commands")
        search.delegate = self
        category.addItems(withTitles: ["All commands"] + Array(Set(commands.map(\.group))).sorted())
        category.target = self; category.action = #selector(filterChanged)
        category.setAccessibilityLabel("Command category")
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        for (identifier, title, width) in [("keys", "Keys", 185.0), ("action", "Command", 385.0), ("group", "Where", 180.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.headerCell = GameTableHeaderCell(textCell: title); column.title = title; column.width = width
            table.addTableColumn(column)
        }
        table.rowHeight = 48 * GameAccessibility.scale
        table.usesAlternatingRowBackgroundColors = false
        table.backgroundColor = .black
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.dataSource = self; table.delegate = self
        table.setAccessibilityLabel("Keyboard commands")
        scroll.documentView = table
        for view in [intro, search, category, scroll, count] {
            view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view)
        }
        NSLayoutConstraint.activate([
            intro.topAnchor.constraint(equalTo: topAnchor), intro.leadingAnchor.constraint(equalTo: leadingAnchor), intro.trailingAnchor.constraint(equalTo: trailingAnchor),
            search.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 16), search.leadingAnchor.constraint(equalTo: leadingAnchor),
            category.centerYAnchor.constraint(equalTo: search.centerYAnchor), category.leadingAnchor.constraint(equalTo: search.trailingAnchor, constant: 12), category.trailingAnchor.constraint(equalTo: trailingAnchor), category.widthAnchor.constraint(equalToConstant: 190),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 12), scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            count.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8), count.leadingAnchor.constraint(equalTo: leadingAnchor), count.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func controlTextDidChange(_ obj: Notification) { refresh() }
    @objc private func filterChanged() { refresh() }
    func refresh() {
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = commands.filter { row in
            (category.indexOfSelectedItem == 0 || row.group == category.titleOfSelectedItem) &&
            (query.isEmpty || "\(row.keys) \(row.action) \(row.group)".localizedCaseInsensitiveContains(query))
        }
        table.reloadData()
        count.stringValue = filtered.isEmpty ? "No matching commands. Try another word or choose All commands." : "\(filtered.count) commands • Shortcuts apply in the context shown. Esc closes this guide."
    }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let command = filtered[row]
        let key = tableColumn?.identifier.rawValue ?? ""
        let label = GameLabel(wrappingLabelWithString: key == "keys" ? command.keys : key == "group" ? command.group : command.action)
        label.setAccessibilityLabel(label.stringValue)
        label.role = key == "group" ? .heading : .body
        return label
    }
}
