import AppKit
import Sub2APIMonitorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var settingsWindow: SettingsWindowController?
    private var snapshot = DashboardSnapshot(accounts: [], usage: [:], errors: [:])
    private var isRefreshing = false
    private var lastError: String?
    private var lastUpdated: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.toolTip = "Sub2API Monitor"

        AppConfiguration.migrateLegacyConfigurationIfNeeded()
        rebuildMenu()

        if (try? AppConfiguration.current()) == nil {
            showSettings()
        } else {
            refresh()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        refreshTask?.cancel()
        if let wakeObserver { NotificationCenter.default.removeObserver(wakeObserver) }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettings()
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
        if lastUpdated.map({ Date().timeIntervalSince($0) > 15 }) ?? true {
            refresh()
        }
    }

    private func refresh(force: Bool = false) {
        guard !isRefreshing else { return }
        guard let configuration = try? AppConfiguration.current() else {
            lastError = "Configuration required"
            rebuildMenu()
            return
        }

        isRefreshing = true
        rebuildMenu()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let client = Sub2APIClient(baseURL: configuration.url, adminKey: configuration.key)
                let nextSnapshot = try await client.fetchSnapshot(force: force)
                try Task.checkCancellation()
                snapshot = nextSnapshot
                lastError = nil
                lastUpdated = Date()
                reconcileSelection()
            } catch is CancellationError {
                return
            } catch {
                lastError = error.localizedDescription
            }
            isRefreshing = false
            refreshTask = nil
            rebuildMenu()
        }
    }

    private func reconcileSelection() {
        let ids = Set(snapshot.accounts.map(\.id))
        if let selected = AppConfiguration.selectedAccountID, ids.contains(selected) { return }
        AppConfiguration.selectedAccountID = snapshot.accounts.first?.id
    }

    private func rebuildMenu() {
        updateStatusTitle()
        menu.removeAllItems()

        if snapshot.accounts.isEmpty {
            let title = lastError ?? (isRefreshing ? "Loading accounts..." : "No accounts")
            menu.addItem(disabledItem(title))
        } else {
            for (index, account) in snapshot.accounts.enumerated() {
                addAccount(account)
                if index < snapshot.accounts.count - 1 { menu.addItem(.separator()) }
            }
        }

        menu.addItem(.separator())
        if let lastError {
            menu.addItem(disabledItem("Error: \(lastError)", color: .systemRed))
        } else if isRefreshing {
            menu.addItem(disabledItem("Refreshing...", color: .secondaryLabelColor))
        }

        menu.addItem(actionItem("Refresh Now", symbol: "arrow.clockwise", action: #selector(refreshNow)))
        menu.addItem(actionItem("Force Upstream Refresh", symbol: "bolt", action: #selector(forceRefresh)))
        menu.addItem(actionItem("Open Account Management", symbol: "arrow.up.forward.app", action: #selector(openAdmin)))
        menu.addItem(actionItem("Settings...", symbol: "gearshape", action: #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Sub2API Monitor", symbol: "power", action: #selector(quit)))
    }

    private func addAccount(_ account: Account) {
        let item = NSMenuItem(title: account.displayName, action: #selector(selectAccount), keyEquivalent: "")
        item.target = self
        item.representedObject = account.id
        item.state = account.id == AppConfiguration.selectedAccountID ? .on : .off
        menu.addItem(item)

        guard let usage = snapshot.usage[String(account.id)] else {
            let message = snapshot.errors[String(account.id)] ?? "No usage data"
            menu.addItem(disabledItem("    \(message)", color: .secondaryLabelColor))
            return
        }
        addWindow(label: "5h", window: usage.fiveHour)
        addWindow(label: "7d", window: usage.sevenDay)
        if let updated = UsageFormatter.updated(usage.updatedAt) {
            menu.addItem(disabledItem("    Updated \(updated)", color: .tertiaryLabelColor, size: 11))
        }
    }

    private func addWindow(label: String, window: UsageWindow?) {
        guard let window else {
            menu.addItem(disabledItem("    \(label): --%", color: .secondaryLabelColor))
            return
        }
        let percent = UsageFormatter.percent(window.utilization)
        let title = "    \(label): \(UsageFormatter.percentText(window.utilization)) · "
            + UsageFormatter.duration(seconds: window.remainingSeconds)
        menu.addItem(disabledItem(title, color: color(for: percent)))
        if let stats = window.windowStats {
            let requests = stats.requests.map(String.init) ?? "--"
            let tokens = UsageFormatter.compact(stats.tokens)
            let cost = stats.displayedCost.map { String(format: "$%.2f", $0) } ?? "$--"
            menu.addItem(disabledItem(
                "    \(requests) req · \(tokens) tokens · \(cost)",
                color: .tertiaryLabelColor,
                size: 11
            ))
        }
    }

    private func updateStatusTitle() {
        guard let selected = AppConfiguration.selectedAccountID,
              let usage = snapshot.usage[String(selected)]
        else {
            statusItem.button?.title = isRefreshing ? "Loading..." : "Sub2API"
            return
        }
        let five = UsageFormatter.percentText(usage.fiveHour?.utilization)
        let seven = UsageFormatter.percentText(usage.sevenDay?.utilization)
        let maximum = [
            UsageFormatter.percent(usage.fiveHour?.utilization),
            UsageFormatter.percent(usage.sevenDay?.utilization),
        ].compactMap { $0 }.max()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: color(for: maximum),
        ]
        statusItem.button?.attributedTitle = NSAttributedString(
            string: "\(five) · \(seven)",
            attributes: attributes
        )
    }

    private func disabledItem(
        _ title: String,
        color: NSColor = .labelColor,
        size: CGFloat = NSFont.systemFontSize
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: color,
        ])
        return item
    }

    private func actionItem(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    private func color(for percent: Int?) -> NSColor {
        guard let percent else { return .secondaryLabelColor }
        if percent >= 95 { return .systemRed }
        if percent >= 80 { return .systemOrange }
        return .systemGreen
    }

    @objc private func selectAccount(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? Int else { return }
        AppConfiguration.selectedAccountID = id
        updateStatusTitle()
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func forceRefresh() {
        refresh(force: true)
    }

    @objc private func openAdmin() {
        guard let server = AppConfiguration.serverURLString,
              let baseURL = try? ServerURL.normalize(server)
        else { return }
        NSWorkspace.shared.open(baseURL.appendingPathComponent("admin/accounts"))
    }

    @objc private func showSettings() {
        let hasStoredKey = ((try? KeychainStore.read()) ?? nil) != nil
        settingsWindow = SettingsWindowController(
            server: AppConfiguration.serverURLString,
            hasStoredKey: hasStoredKey
        ) { [weak self] server, key in
            try AppConfiguration.save(server: server, key: key)
            self?.configurationDidChange()
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configurationDidChange() {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        snapshot = DashboardSnapshot(accounts: [], usage: [:], errors: [:])
        lastError = nil
        lastUpdated = nil
        refresh()
    }
}
