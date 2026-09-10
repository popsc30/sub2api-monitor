import AppKit

@MainActor
enum ApplicationMenu {
    static func install() {
        let mainMenu = NSMenu(title: "Main Menu")
        mainMenu.addItem(applicationMenuItem())
        mainMenu.addItem(editMenuItem())
        NSApp.mainMenu = mainMenu
    }

    private static func applicationMenuItem() -> NSMenuItem {
        let rootItem = NSMenuItem()
        let menu = NSMenu(title: "Sub2API Monitor")
        let quitItem = NSMenuItem(
            title: "Quit Sub2API Monitor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)
        rootItem.submenu = menu
        return rootItem
    }

    private static func editMenuItem() -> NSMenuItem {
        let rootItem = NSMenuItem()
        let menu = NSMenu(title: "Edit")
        menu.addItem(command("Undo", action: Selector(("undo:")), key: "z"))

        let redo = command("Redo", action: Selector(("redo:")), key: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(command("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(command("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(command("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(command("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        rootItem.submenu = menu
        return rootItem
    }

    private static func command(_ title: String, action: Selector, key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }
}
