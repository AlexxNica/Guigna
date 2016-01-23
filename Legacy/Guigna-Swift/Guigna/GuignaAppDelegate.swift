import Cocoa
import WebKit
import ScriptingBridge

@NSApplicationMain
class GuignaAppDelegate: NSObject, GAppDelegate, NSApplicationDelegate, NSMenuDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate {

    var agent: GAgent = GAgent()
    @IBOutlet var defaults: NSUserDefaultsController!

    @IBOutlet var window: NSWindow!
    @IBOutlet var sourcesOutline: NSOutlineView!
    @IBOutlet var itemsTable: NSTableView!
    @IBOutlet var searchField: NSSearchField!
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var infoText: NSTextView!
    @IBOutlet var webView: WebView!
    @IBOutlet var logText: NSTextView!
    @IBOutlet var segmentedControl: NSSegmentedControl!
    @IBOutlet var commandsPopUp: NSPopUpButton!
    @IBOutlet var shellDisclosure: NSButton!
    @IBOutlet var cmdline: NSTextField!
    @IBOutlet var statusField: NSTextField!
    @IBOutlet var clearButton: NSButton!
    @IBOutlet var screenshotsButton: NSButton!
    @IBOutlet var moreButton: NSButton!
    @IBOutlet var statsLabel: NSTextField!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var tableProgressIndicator: NSProgressIndicator!
    @IBOutlet var applyButton: NSToolbarItem!
    @IBOutlet var stopButton: NSToolbarItem!
    @IBOutlet var syncButton: NSToolbarItem!

    var statusItem: NSStatusItem!
    @IBOutlet var statusMenu: NSMenu!
    @IBOutlet var toolsMenu: NSMenu!
    @IBOutlet var markMenu: NSMenu!

    @IBOutlet var optionsPanel: NSPanel!
    @IBOutlet var optionsProgressIndicator: NSProgressIndicator!
    @IBOutlet var optionsStatusField: NSTextField!
    @IBOutlet var themesSegmentedControl: NSSegmentedControl!

    var terminal: AnyObject! // TerminalApplication!
    var shell: AnyObject! // TerminalTab!
    var shellWindow: NSObject! // TerminalWindow!
    var browser: AnyObject! // SafariApplication!

    @IBOutlet var sourcesController: NSTreeController!
    @IBOutlet var itemsController: NSArrayController!

    var sources = [GSource]()
    var systems = [GSystem]()
    var scrapes = [GScrape]()
    var repos   = [GRepo]()

    var items = [GItem]()
    var allPackages = [GPackage]()
    var packagesIndex = [String: GPackage](minimumCapacity: 150000)
    var markedItems = [GItem]()
    var marksCount = 0
    var selectedSegment = "Info"
    var previousSegment = 0
    let APPDIR = ("~/Library/Application Support/Guigna" as NSString).stringByExpandingTildeInPath

    dynamic var tableFont: NSFont!
    dynamic var tableTextColor: NSColor!
    dynamic var logTextColor: NSColor!
    dynamic var linkTextAttributes: [String : AnyObject]!
    dynamic var sourceListBackgroundColor: NSColor!

    dynamic var adminPassword: String?
    var minuteTimer: NSTimer?
    dynamic var ready = false

    var shellColumns: Int {
        get {
            let attrs = [NSFontAttributeName: NSFont(name: "Andale Mono", size: 11.0)!]
            let charWidth = ("MMM".sizeWithAttributes(attrs).width - "M".sizeWithAttributes(attrs).width) / 2.0
            let columns = Int(round((infoText.frame.size.width - 16.0) / charWidth + 0.5))
            return columns
        }
    }

    func status(var msg: String) {
        if msg.hasSuffix("...") {
            progressIndicator.startAnimation(self)
            if statusField.stringValue.hasPrefix("Executing") {
                msg = "\(statusField.stringValue) \(msg)"
            }
        } else {
            progressIndicator.stopAnimation(self)
            self.ready = true
        }
        statusField.stringValue = msg
        statusField.toolTip = msg
        statusField.display()
        if msg.hasSuffix("...") {
            statusItem.title = "💤"
        } else {
            statusItem.title = "😺"
        }
        statusMenu.itemAtIndex(0)?.title = msg
        statusItem.toolTip = msg
    }

    func info(text: String) {
        infoText.string = text
        infoText.scrollRangeToVisible(NSRange(location: 0, length: 0))
        infoText.display()
        tabView.display()
    }

    func log(text: String) {
        let attributedString = NSAttributedString(string: text, attributes: [NSFontAttributeName: NSFont(name: "Andale Mono", size:11.0)!, NSForegroundColorAttributeName: logTextColor])
        let storage = logText.textStorage!
        storage.beginEditing()
        storage.appendAttributedString(attributedString)
        storage.endEditing()
        logText.display()
        logText.scrollRangeToVisible(NSRange(location: logText.string!.length, length: 0))
        tabView.display()
    }


    func applicationDidFinishLaunching(aNotification: NSNotification) {

        tableProgressIndicator.startAnimation(self)

        let defaultsTransformer = GDefaultsTransformer()
        NSValueTransformer.setValueTransformer(defaultsTransformer, forName: "GDefaultsTransformer")
        let statusTransformer = GStatusTransformer()
        NSValueTransformer.setValueTransformer(statusTransformer, forName: "GStatusTransformer")
        let markTransformer = GMarkTransformer()
        NSValueTransformer.setValueTransformer(markTransformer, forName: "GMarkTransformer")
        let sourceTransformer = GSourceTransformer()
        NSValueTransformer.setValueTransformer(sourceTransformer, forName: "GSourceTransformer")

        statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1) // NSVariableStatusItemLength
        statusItem.title = "😺"
        statusItem.highlightMode = true
        statusItem.menu = statusMenu
        itemsTable.doubleAction = "showMarkMenu:"
        window.titleVisibility = .Hidden

        infoText.font = NSFont(name: "Andale Mono", size: 11.0)
        logText.font  = NSFont(name: "Andale Mono", size: 11.0)
        let welcomeMsg = "\n\t\t\t\t\tWelcome to Guigna\n\t\tGUIGNA: the GUI of Guigna is Not by Apple  :)\n\n\t[Sync] to update from remote repositories.\n\tRight/double click a package to mark it.\n\t[Apply] to commit the changes to a [Shell].\n\n\tYou can try other commands typing in the yellow prompt.\n\tTip: Command-click to combine sources.\n\tWarning: keep the Guigna shell open!\n\n\n\t\t\t\tTHIS IS ONLY A PROTOTYPE.\n\n\n\t\t\t\tguido.soranzio@gmail.com"
        info(welcomeMsg)
        infoText.checkTextInDocument(nil)

        let columnsMenu     = NSMenu(title: "ItemsColumnsMenu")
        let viewColumnsMenu = NSMenu(title: "ItemsColumnsMenu")
        for menu in [columnsMenu, viewColumnsMenu] {
            for column in itemsTable.tableColumns {
                let menuItem = NSMenuItem(title: column.headerCell.stringValue, action: "toggleTableColumn:", keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = column
                menu.addItem(menuItem)
            }
            menu.delegate = self
        }
        itemsTable.headerView!.menu = columnsMenu
        let viewMenu = NSApplication.sharedApplication().mainMenu!.itemWithTitle("View")!
        viewMenu.submenu!.addItem(NSMenuItem.separatorItem())
        let columnsMenuItem = NSMenuItem(title: "Columns", action: nil, keyEquivalent: "")
        columnsMenuItem.submenu = viewColumnsMenu
        viewMenu.submenu!.addItem(columnsMenuItem)

        agent.appDelegate = self

        allPackages.reserveCapacity(150000)

        system("mkdir -p '\(APPDIR)'")
        system("touch '\(APPDIR)/output'")
        system("touch '\(APPDIR)/sync'")
        for dir in ["MacPorts", "Homebrew", "Fink", "pkgsrc", "FreeBSD", "Gentoo"] {
            system("mkdir -p '\(APPDIR)/\(dir)'")
        }

        system("osascript -e 'tell application \"Terminal\" to close (windows whose name contains \"Guigna \")'")
        terminal = SBApplication(bundleIdentifier: "com.apple.Terminal")
        let guignaFunction = "guigna() { osascript -e 'tell app \"Guigna\"' -e \"open POSIX file \\\"\(APPDIR)/$2\\\"\" -e 'end' &>/dev/null; }"
        let initScript = "unset HISTFILE ; " + guignaFunction
        shell = terminal.doScript(initScript, `in`: nil)
        shell.setValue("Guigna", forKey: "customTitle")
        for window in terminal.valueForKey("windows") as! [NSObject] {
            if (window.valueForKey("name") as! NSString).containsString("Guigna ") {
                shellWindow = window
            }
        }
        sourceListBackgroundColor = sourcesOutline.backgroundColor
        linkTextAttributes = infoText.linkTextAttributes
        if defaults["Theme"] == nil {
            defaults["Theme"] = "Default"
        }
        let theme = defaults["Theme"] as! String
        if theme == "Default" {
            shell.setValue(NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.8, alpha: 1.0), forKey: "backgroundColor") // light yellow
            shell.setValue(NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), forKey: "normalTextColor")
            tableFont = NSFont.controlContentFontOfSize(NSFont.systemFontSizeForControlSize(.SmallControlSize))
            tableTextColor = NSColor.blackColor()
            logTextColor = NSColor.blackColor()
        } else {
            themesSegmentedControl.selectedSegment = ["Default", "Retro"].indexOf(theme)!
            applyTheme(theme)
        }

        let knownPaths = ["MacPorts": "/opt/local", "Homebrew": "/usr/local", "pkgsrc": "/usr/pkg", "Fink": "/sw"]
        for (system, prefix) in knownPaths {
            if "\(prefix)_off".exists || "\(prefix)/bin_off".exists {
                let alert = NSAlert()
                alert.alertStyle = .CriticalAlertStyle
                alert.messageText = "Hidden system detected."
                alert.informativeText = "The path to \(system) is currently hidden by an \"_off\" suffix."
                alert.addButtonWithTitle("Unhide")
                alert.addButtonWithTitle("Continue")
                if alert.runModal() == NSAlertFirstButtonReturn {
                    if prefix != "/usr/local" {
                        executeAsRoot("mv \(prefix)_off \(prefix)")
                    } else {
                        executeAsRoot("for dir in bin etc include lib opt share ; do sudo mv \(prefix)/\"$dir\"{_off,} ; done")
                    }
                }
            }
        }

        var portPath = MacPorts.prefix + "/bin/port"
        var brewPath = Homebrew.prefix + "/bin/brew"
        let paths = agent.output("/bin/bash -l -c which__port__brew").split("\n")
        for path in paths {
            if path.hasSuffix("port") {
                portPath = path
            } else if path.hasSuffix("brew") {
                brewPath = path
            }
        }

        terminal.doScript("clear ; printf \"\\e[3J\" ; echo Welcome to Guigna! ; echo", `in`:shell)

        if portPath.exists || "\(APPDIR)/MacPorts/PortIndex".exists {
            if defaults["MacPortsStatus"] == nil {
                defaults["MacPortsStatus"] = GState.On.rawValue
            }
        }
        if defaults["MacPortsParsePortIndex"] == nil {
            defaults["MacPortsParsePortIndex"] = true
        }
        if defaults["MacPortsStatus"] != nil && defaults["MacPortsStatus"] == GState.On.rawValue {
            let macports = MacPorts(agent: agent)
            if !portPath.exists {
                macports.mode = .Online
            }
            if !(macports.mode == .Online && !"\(APPDIR)/MacPorts/PortIndex".exists) {
                systems.append(macports)
                if macports.cmd != portPath {
                    macports.prefix = ((portPath as NSString).stringByDeletingLastPathComponent as NSString).stringByDeletingLastPathComponent
                    macports.cmd = portPath
                }
            }
        }

        if brewPath.exists {
            if defaults["HomebrewStatus"] == nil {
                defaults["HomebrewStatus"] = GState.On.rawValue
            }
        }
        if defaults["HomebrewStatus"] != nil && defaults["HomebrewStatus"] == GState.On.rawValue {
            if brewPath.exists { // TODO: online mode
                let homebrew = Homebrew(agent: agent)
                systems.append(homebrew)
                if homebrew.cmd != brewPath {
                    homebrew.prefix = ((brewPath as NSString).stringByDeletingLastPathComponent as NSString).stringByDeletingLastPathComponent
                    homebrew.cmd = brewPath
                }
                if "\(homebrew.prefix)/Library/Taps/caskroom/homebrew-cask/cmd/brew-cask.rb".exists {
                    let homebrewcasks = HomebrewCasks(agent: agent)
                    systems.append(homebrewcasks)
                    homebrewcasks.prefix = homebrew.prefix
                    homebrewcasks.cmd = brewPath + " cask"
                }
            }
        }

        if "/sw/bin/fink".exists {
            if defaults["FinkStatus"] == nil {
                defaults["FinkStatus"] = GState.On.rawValue
            }
        }
        if defaults["FinkStatus"] != nil && defaults["FinkStatus"] == GState.On.rawValue {
            let fink = Fink(agent: agent)
            if !"/sw/bin/fink".exists {
                fink.mode = .Online
            }
            systems.append(fink)
        }

        // TODO detect pkgsrc in /opt/pkg

        // TODO: Index user defaults
        if "/usr/pkg/sbin/pkg_info".exists || "\(APPDIR)/pkgsrc/INDEX".exists {
            if defaults["pkgsrcStatus"] == nil {
                defaults["pkgsrcStatus"] = GState.On.rawValue
                defaults["pkgsrcCVS"] = true
            }
        }
        if defaults["pkgsrcStatus"] != nil && defaults["pkgsrcStatus"] == GState.On.rawValue {
            let pkgsrc = Pkgsrc(agent: agent)
            if !"/usr/pkg/sbin/pkg_info".exists {
                pkgsrc.mode = .Online
            }
            systems.append(pkgsrc)
        }

        if "/opt/pkg/bin/pkgin".exists {
            if defaults["pkginStatus"] == nil {
                defaults["pkginStatus"] = GState.On.rawValue
            }
        }
        if defaults["pkginStatus"] != nil && defaults["pkginStatus"] == GState.On.rawValue {
            let pkgin = Pkgin(agent: agent)
            if !"/opt/pkg/bin/pkgbin".exists {
                pkgin.mode = .Online
            }
            systems.append(pkgin)
        }

        if "\(APPDIR)/FreeBSD/INDEX".exists {
            if defaults["FreeBSDStatus"] == nil {
                defaults["FreeBSDStatus"] = GState.On.rawValue
            }
        }
        if defaults["FreeBSDStatus"] != nil && defaults["FreeBSDStatus"] == GState.On.rawValue {
            let freebsd = FreeBSD(agent: agent)
            freebsd.mode = .Online
            systems.append(freebsd)
        }

        if "/usr/local/bin/rudix".exists {
            if defaults["RudixStatus"] == nil {
                defaults["RudixStatus"] = GState.On.rawValue
            }
        }
        if defaults["RudixStatus"] != nil && defaults["RudixStatus"] == GState.On.rawValue {
            let rudix = Rudix(agent: agent)
            if !"/usr/local/bin/rudix".exists {
                rudix.mode = .Online
            }
            systems.append(rudix)
        }

        systems.append(MacOSX(agent: agent))

        if defaults["iTunesStatus"] == nil {
            defaults["iTunesStatus"] = GState.On.rawValue
        }
        if defaults["iTunesStatus"] != nil && defaults["iTunesStatus"] == GState.On.rawValue {
            let itunes = ITunes(agent: agent)
            systems.append(itunes)
        }

        if defaults["DebugMode"] == nil {
            defaults["DebugMode"] = false
        }

        if defaults["ScrapesCount"] == nil {
            defaults["ScrapesCount"] = 15
        }

        repos   += [Native(agent: agent)]
        scrapes += [PkgsrcSE(agent: agent), Freecode(agent: agent), Debian(agent: agent), CocoaPods(agent: agent), PyPI(agent: agent), RubyGems(agent: agent), MacUpdate(agent: agent), AppShopper(agent: agent), AppShopperIOS(agent: agent)]

        let source1 = GSource(name: "SYSTEMS")
        source1.categories = systems
        let source2 = GSource(name: "STATUS")
        source2.categories = [GSource(name: "installed"), GSource(name: "outdated"), GSource(name: "inactive")]
        let source3 = GSource(name: "REPOS")
        source3.categories = repos
        let source4 = GSource(name: "SCRAPES")
        source4.categories = scrapes
        sourcesController.content = [source1, GSource(name: ""), source2, GSource(name: ""),  source3, GSource(name: ""), source4]
        sourcesOutline.reloadData()
        sourcesOutline.expandItem(nil, expandChildren: true)
        sourcesOutline.display()

        browser =  SBApplication(bundleIdentifier: "com.apple.Safari")

        let queue = dispatch_queue_create("name.Guigna", DISPATCH_QUEUE_CONCURRENT)
        dispatch_async(queue) {
            self.reloadAllPackages()
        }

        minuteTimer = NSTimer.scheduledTimerWithTimeInterval(60.0, target: self, selector: "minuteCheck:", userInfo: nil, repeats: true)

        self.applyButton.enabled = false
        self.stopButton.enabled = false
        self.syncButton.enabled = false


        self.options(self)
    }

    func applicationDidBecomeActive(aNotification: NSNotification) {
        if shellWindow != nil && (self.shellWindow.valueForKey("name") as! NSString).containsString("sudo") {
            raiseShell(self)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(theApp: NSApplication) -> Bool {
        return true
    }

    func windowWillClose(notification: NSNotification) {
        if self.ready {
            system("osascript -e 'tell application \"Terminal\" to close (windows whose name contains \"Guigna \")'")
        }
    }

    func splitView(splitView: NSSplitView, shouldAdjustSizeOfSubview subview: NSView) -> Bool {
        return !subview.isEqualTo(splitView.subviews[0])
    }

    func outlineView(outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        let source = item.representedObject as! GSource
        return source.categories != nil && !(source is GSystem)
    }

    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        let source = item.representedObject as! GSource
        if !(item.parentNode!!.representedObject is GSource) {
            return outlineView.makeViewWithIdentifier("HeaderCell", owner:self) as! NSTableCellView
        } else {
            if source.categories == nil && (item.parentNode!!.representedObject is GSystem) {
                return outlineView.makeViewWithIdentifier("LeafCell", owner:self) as! NSTableCellView
            } else {
                return outlineView.makeViewWithIdentifier("DataCell", owner:self) as! NSTableCellView
            }
        }
    }

    func outlineView(outlineView: NSOutlineView, shouldShowOutlineCellForItem item: AnyObject) -> Bool {
        return (item.representedObject as! GSource) is GSystem
    }


    func application(sender: NSApplication, openFile filename: String) -> Bool {
        status("Ready.")
        var history = shell.valueForKey("history") as! String
        if adminPassword != nil {
            let sudoCommand = "echo \"\(adminPassword!)\" | sudo -S"
            history = history.replace(sudoCommand, "sudo")
        }
        history = history.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        log(history + "\n")
        stopButton.enabled = false

        if filename == "\(APPDIR)/output" {
            status("Analyzing committed changes...")
            if markedItems.count > 0 {
                let affectedSystems = NSMutableSet()
                for item in markedItems {
                    affectedSystems.addObject(item.system)
                }
                // refresh statuses and versions
                for system in affectedSystems.allObjects as! [GSystem] { // Explicit GStatus otherwise does not compile
                    for pkg in (system.items.filter { $0.status == GStatus.Inactive}) as! [GPackage] {
                        itemsController.removeObject(pkg)
                    }
                    system.installed()
                    for pkg in (system.items.filter { $0.status == .Inactive}) as! [GPackage] {
                        let predicate = itemsController.filterPredicate
                        itemsController.addObject(pkg)
                        itemsController.filterPredicate = predicate
                    }
                }
                itemsTable.reloadData()
                var mark: GMark
                let markNames = ["None", "Install", "Uninstall", "Deactivate", "Upgrade", "Fetch", "Clean"]
                var markName: String
                for item in markedItems {
                    mark = item.mark
                    markName = markNames[Int(mark.rawValue)]

                    // TODO verify command did really complete

                    if mark == GMark.Install { // explicit GMark otherwise it doesn't compile
                        marksCount--

                    } else if mark == .Uninstall {
                        marksCount--

                    } else if mark == .Deactivate {
                        marksCount--

                    } else if mark == .Upgrade {
                        marksCount--

                    } else if mark == .Fetch {
                        marksCount--
                    }

                    let itemSystem = item.system
                    let systemName = itemSystem.name
                    log("😺 \(markName) \(systemName) \(item.name): DONE\n")
                    if mark == .Uninstall && (systemName == "Mac OS X" || systemName == "iTunes") {
                        itemsController.removeObject(item)
                        itemSystem.mutableArrayValueForKey("items").removeObject(item)
                    } else {
                        item.mark = .NoMark
                    }
                    itemsTable.reloadData()
                }
                self.updateMarkedSource()
                if (self.terminal.valueForKey("frontmost") as! NSObject) == false {
                    let notification = NSUserNotification()
                    notification.title = "Ready."
                    // notification.subtitle = @"%ld changes applied";
                    notification.informativeText = "The changes to the marked packages have been applied."
                    notification.soundName = NSUserNotificationDefaultSoundName
                    NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(notification)
                }
            }
            status("Shell: OK.")

        } else if filename == "\(APPDIR)/sync" {
            let queue = dispatch_queue_create("name.Guigna", DISPATCH_QUEUE_CONCURRENT)
            dispatch_async(queue) {
                self.reloadAllPackages()
            }
        }
        return true
    }

    func reloadAllPackages() {

        self.ready = false
        dispatch_sync(dispatch_get_main_queue()) {
            self.itemsController.filterPredicate = nil
            self.itemsController.removeObjectsAtArrangedObjectIndexes(NSIndexSet(indexesInRange: NSRange(location: 0, length: self.itemsController.arrangedObjects.count)))
            self.itemsController.sortDescriptors = []
            self.tableProgressIndicator.startAnimation(self)
        }
        var updated = 0
        var `new` = 0
        var previousPackage: GPackage?

        var newIndex = [String: GPackage](minimumCapacity: 150000)

        for system in systems {
            let systemName = system.name
            dispatch_sync(dispatch_get_main_queue()) {
                self.status("Indexing \(systemName)...")
            }
            system.list()
            dispatch_sync(dispatch_get_main_queue()) {
                self.itemsController.addObjects(system.items)
                self.itemsTable.display()
            }
            if packagesIndex.count > 0 && !(systemName == "Mac OS X" || systemName == "FreeBSD" || systemName == "iTunes") {
                for package in system.items as! [GPackage] {
                    if package.status == .Inactive {
                        continue
                    }
                    previousPackage = packagesIndex[package.key()]
                    // TODO: keep mark
                    if previousPackage == nil {
                        package.status = .New
                        `new` += 1
                    } else if previousPackage!.version != package.version {
                        package.status = .Updated
                        updated += 1
                    }
                }
            }
            for (key, value) in system.index {
                newIndex[key] = value
            }
        }

        if packagesIndex.count > 0 {
            dispatch_sync(dispatch_get_main_queue()) {
                self.sourcesOutline.setDelegate(nil)
                var name: String
                let sourcesContent = self.sourcesController.content as! NSArray
                let statusSource = sourcesContent[2] as! GSource
                let statuses = statusSource.categories! as! [GSource]
                let statusesMutableArray = statusSource.mutableArrayValueForKey("categories")
                var currentUpdated = statuses.filter { $0.name.hasPrefix("updated") }
                if currentUpdated.count > 0 && updated == 0 {
                    statusesMutableArray.removeObject(currentUpdated[0])
                }
                if updated > 0 {
                    name = "updated (\(updated))"
                    if currentUpdated.count == 0 {
                        let updatedSource = GSource(name: name)
                        statusesMutableArray.addObject(updatedSource)
                    } else {
                        (currentUpdated[0] as GSource).name = name
                    }
                }
                var currentNew = statuses.filter { $0.name.hasPrefix("new") }
                if currentNew.count > 0 && `new` == 0 {
                    statusesMutableArray.removeObject(currentNew[0])
                }
                if `new` > 0 {
                    name = "new (\(`new`))"
                    if currentNew.count == 0 {
                        let newSource = GSource(name: name)
                        statusesMutableArray.addObject(newSource)
                    } else {
                        (currentNew[0] as GSource).name = name
                    }
                }
                self.sourcesOutline.setDelegate(self)
                self.packagesIndex.removeAll(keepCapacity: true)
                self.allPackages.removeAll()
            }
        } else {
            dispatch_sync(dispatch_get_main_queue()) {
                self.sourcesOutline.setDelegate(nil)
                self.status("Indexing categories...")
                for system in (((self.sourcesController.content as! NSArray)[0] as! GSource).categories as! [GSystem]) {
                    // duplicate code is addSystem()
                    system.categories = []
                    let categories = system.mutableArrayValueForKey("categories")
                    for category in system.categoriesList() {
                        let categorySource = GSource(name: category)
                        if system.name == "Homebrew" {
                            if category == "cask" {
                                continue
                            }
                            categorySource.homepage = system.logpage.replace("homebrew", "homebrew-" + category)
                        }
                        categories.addObject(categorySource)
                    }
                }
                self.sourcesOutline.setDelegate(self)
                self.sourcesOutline.reloadData()
                self.sourcesOutline.display()
            }
        }

        for system in systems {
            // avoid adding duplicates of inactive packages already added by system.list
            allPackages += system.items.filter { $0.status != .Inactive} as! [GPackage]
        }

        packagesIndex = newIndex
        markedItems.removeAll()
        marksCount = 0

        dispatch_sync(dispatch_get_main_queue()) {
            self.itemsController.sortDescriptors = [NSSortDescriptor(key: "status", ascending: false)]
            self.updateMarkedSource()
            self.tableProgressIndicator.stopAnimation(self)
            self.applyButton.enabled = false
            self.stopButton.enabled = false
            self.syncButton.enabled = true
            self.ready = true
            self.status("OK.")
        }
    }

    @IBAction func syncAction(sender: AnyObject) {
        tableProgressIndicator.startAnimation(self)
        info("[Contents not yet available]")
        updateCmdLine("")
        syncButton.enabled = false
        stopButton.enabled = true
        self.sync(sender)
    }

    func sync(sender: AnyObject) {
        self.ready = false
        status("Syncing...")
        var systemsToUpdateAsync = [GSystem]()
        var systemsToUpdate = [GSystem]()
        var systemsToList = [GSystem]()
        for system in systems {
            if system.name == "Homebrew Casks" {
                continue
            }
            let updateCmd = system.updateCmd
            if updateCmd == nil {
                systemsToList.append(system)
            } else if updateCmd.hasPrefix("sudo") {
                systemsToUpdateAsync.append(system)
            } else {
                systemsToUpdate.append(system)
            }
        }
        if systemsToUpdateAsync.count > 0 {
            var updateCommands = [String]()
            for system in systemsToUpdateAsync {
                updateCommands.append(system.updateCmd)
            }
            execute(updateCommands.join(" ; "), baton: "sync")
        }
        if systemsToUpdate.count + systemsToList.count > 0 {
            segmentedControl.selectedSegment = -1
            updateTabView(nil)
            let queue = dispatch_queue_create("name.Guigna", DISPATCH_QUEUE_CONCURRENT)
            for system in systemsToList {
                status("Syncing \(system.name)...")
                dispatch_async(queue) {
                    let _ = system.list()
                }
            }
            for system in systemsToUpdate {
                status("Syncing \(system.name)...")
                log("😺===> \(system.updateCmd)\n")
                dispatch_async(queue) {
                    let outputLog = self.agent.output(system.updateCmd)
                    dispatch_sync(dispatch_get_main_queue()) {
                        self.log(outputLog)
                    }
                }
            }
            dispatch_barrier_async(queue) {
                if systemsToUpdateAsync.count == 0 {
                    dispatch_async(queue) {
                        self.reloadAllPackages()
                    }
                }
            }
        }
    }

    func outlineViewSelectionDidChange(notification: NSNotification) {
        sourcesSelectionDidChange(notification)
    }

    func sourcesSelectionDidChange(sender: AnyObject!) {
        let selectedObjects = sourcesController.selectedObjects as NSArray
        var selectedSources = selectedObjects.copy() as! [GSource]
        tableProgressIndicator.startAnimation(self)
        let selectedNames = selectedSources.map {$0.name}
        var selectedSystems = [GSystem]()
        for system in systems {
            if let idx = selectedNames.indexOf(system.name) {
                selectedSystems.append(system)
                selectedSources.removeAtIndex(idx)
            }
        }
        if selectedSystems.count == 0 {
            selectedSystems = systems
        }
        if selectedSources.count == 0 {
            selectedSources.append((sourcesController.content as! NSArray)[0] as! GSource) // SYSTEMS
        }
        var src: String
        let filter = searchField.stringValue
        itemsController.filterPredicate = nil
        itemsController.removeObjectsAtArrangedObjectIndexes(NSIndexSet(indexesInRange: NSRange(location: 0, length: itemsController.arrangedObjects.count)))
        itemsController.sortDescriptors = []
        var first = true
        for source in selectedSources {
            src = source.name
            if source is GScrape {
                itemsTable.display()
                (source as! GScrape).pageNumber = 1
                updateScrape(source as! GScrape)
            } else {
                if first {
                    itemsController.addObjects(allPackages)
                }
                for system in selectedSystems {
                    var packages = [GPackage]()
                    packages.reserveCapacity(50000)

                    if src == "installed" {
                        if first {
                            status("Verifying installed packages...")
                            itemsController.filterPredicate = NSPredicate(format: "status == \(GStatus.UpToDate.rawValue)")
                            itemsTable.display()
                        }
                        packages = system.installed()

                    } else if src == "outdated" {
                        if first {
                            status("Verifying outdated packages...")
                            itemsController.filterPredicate = NSPredicate(format: "status == \(GStatus.Outdated.rawValue)")
                            itemsTable.display()
                        }
                        packages = system.outdated()

                    } else if src == "inactive" {
                        if first {
                            status("Verifying inactive packages...")
                            itemsController.filterPredicate = NSPredicate(format: "status == \(GStatus.Inactive.rawValue)")
                            itemsTable.display()
                        }
                        packages = system.inactive()

                    } else if src.hasPrefix("updated") || src.hasPrefix("new") {
                        src = src.split()[0]
                        let st: GStatus = (src == "updated") ? .Updated : .New
                        if first {
                            status("Verifying \(src) packages...")
                            itemsController.filterPredicate = NSPredicate(format: "status == \(st.rawValue)")
                            itemsTable.display()
                            packages = (itemsController.arrangedObjects as! NSArray).mutableCopy() as! [GPackage]
                        }

                    } else if src.hasPrefix("marked") {
                        src = src.split()[0]
                        if first {
                            status("Verifying marked packages...")
                            itemsController.filterPredicate = NSPredicate(format: "mark != 0")
                            itemsTable.display()
                            packages = (itemsController.arrangedObjects as! NSArray).mutableCopy() as! [GPackage]
                        }

                    } else if !(src == "SYSTEMS" || src == "STATUS" || src == "") { // a category was selected
                        if first {
                            segmentedControl.selectedSegment = 2 // shows System Log
                            self.updateTabView(nil)
                        }
                        itemsController.filterPredicate = NSPredicate(format: "categories CONTAINS[c] '\(src)'")
                        packages = system.items.filter { $0.categories != nil && $0.categories!.contains(src) } as! [GPackage]

                    } else { // a system was selected
                        itemsController.filterPredicate = nil
                        itemsTable.display()
                        packages = system.items as! [GPackage]
                        if first && itemsController.selectedObjects.count == 0 {
                            if sourcesController.selectedObjects.count == 1 {
                                if sourcesController.selectedObjects[0] is GSystem {
                                    segmentedControl.selectedSegment = 2 // shows System Log
                                    self.updateTabView(nil)
                                }
                            }
                        }
                    }

                    if first {
                        itemsController.filterPredicate = nil
                        itemsController.removeObjectsAtArrangedObjectIndexes(NSIndexSet(indexesInRange: NSRange(location: 0, length: itemsController.arrangedObjects.count)))
                        itemsController.sortDescriptors = []
                        first = false
                    }

                    itemsController.addObjects(packages)
                    itemsTable.display()
                    // TODO: port
                    //                    GMark mark = GNoMark;
                    //                    if ([packagesIndex count] > 0) {
                    //                        for (GPackage *package in packages) {
                    //                            if (package.status != GInactiveStatus)
                    //                            mark = ((GPackage *)packagesIndex[[package key]]).mark;
                    //                            else {
                    //                                // TODO:
                    //                                NSArray *inactivePackages = [allPackages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@ && installed == %@", package.name, package.installed]];
                    //                                if ([inactivePackages count] > 0)
                    //                                mark = ((GPackage*)inactivePackages[0]).mark;
                    //                            }
                    //                            if (mark != GNoMark)
                    //                            package.mark = mark;
                    //                        }
                    //                        [itemsTable display];
                    //                    }
                }
            }
        }


        searchField.stringValue = filter
        searchField.performClick(self)

        if selectedSystems.count > 0 {
            itemsController.sortDescriptors = [NSSortDescriptor(key: "status", ascending: false)]
        }
        tableProgressIndicator.stopAnimation(self)
        if self.ready && !(statusField.stringValue.hasPrefix("Executing") || statusField.stringValue.hasPrefix("Loading")) {
            status("OK.")
        }
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        let selectedItems = itemsController.selectedObjects
        var item: GItem! = nil
        if selectedItems.count == 1 {
            item = selectedItems[0] as? GItem
        }
        if item == nil {
            info("[No package selected]")
        }
        if selectedItems.count > 1 || selectedSegment == "Shell" || (selectedSegment == "Log" && cmdline.stringValue == item?.log) {
            segmentedControl.selectedSegment = 0
            selectedSegment = "Info"
        }
        if selectedItems.count > 1 {
            let itemList = selectedItems.map {$0.name}.join("\n")
            info("[Multiple selection]\n\n\(itemList)")
        }
        updateTabView(item)
    }

    func toggleTableColumn(sender: NSMenuItem) {
        let column = sender.representedObject as! NSTableColumn
        column.hidden = !column.hidden
    }

    @IBAction func switchSegment(sender: NSSegmentedControl) {
        selectedSegment = sender.labelForSegment(sender.selectedSegment)!
        let selectedItems = itemsController.selectedObjects
        var item: GItem? = nil
        if selectedItems.count > 0 {
            item = selectedItems[0] as? GItem
        }
        if selectedSegment == "Shell" || selectedSegment == "Info" || selectedSegment == "Home" || selectedSegment == "Log" || selectedSegment == "Contents" || selectedSegment == "Spec" || selectedSegment == "Deps" {
            updateTabView(item)
        }
    }


    @IBAction func toggleShell(button: NSButton) {
        let selectedItems = itemsController.selectedObjects
        var item: GItem? = nil
        if selectedItems.count > 0 {
            item = selectedItems[0] as? GItem
        }
        if button.state == NSOnState {
            previousSegment = segmentedControl.selectedSegment
            segmentedControl.selectedSegment = -1
            selectedSegment = "Shell"
            updateTabView(item)
        } else {
            if previousSegment != -1 {
                segmentedControl.selectedSegment = previousSegment
                updateTabView(item)
            }
        }
    }

    func updateTabView(item: GItem!) {
        if segmentedControl.selectedSegment == -1 {
            shellDisclosure.state = NSOnState
            selectedSegment = "Shell"
        } else {
            shellDisclosure.state = NSOffState
            selectedSegment = segmentedControl.labelForSegment(segmentedControl.selectedSegment)!
        }
        clearButton.hidden = (selectedSegment != "Shell")
        screenshotsButton.hidden = (!(item?.source is GScrape) || selectedSegment != "Home")
        moreButton.hidden =  !(item?.source is GScrape)

        if selectedSegment == "Home" || selectedSegment == "Log" {
            tabView.selectTabViewItemWithIdentifier("web")
            webView.display()
            var page: String! = nil
            if item != nil {
                if selectedSegment == "Log" {
                    if item.source.name == "MacPorts" && item.categories == nil {
                        page = packagesIndex[(item as! GPackage).key()]!.log
                    } else {
                        page = item.log
                    }
                } else {
                    if item.homepage == nil {
                        item.homepage = item.home
                    }
                    page = item.homepage
                }
            } else { // item is nil
                page = cmdline.stringValue
                if page.hasPrefix("Loading") {
                    page = page.substring(8, page.length - 11)
                }
                if !page.contains("http") && !page.contains("www") {
                    page = "http://github.com/gui-dos/Guigna/"
                }
                if sourcesController.selectedObjects.count == 1 {
                    if sourcesController.selectedObjects[0] is GSystem {
                        page = (sourcesController.selectedObjects[0] as! GSystem).logpage
                    } else {
                        if let homepage = (sourcesController.selectedObjects[0] as! GSource).homepage {
                            page = homepage
                        }
                    }
                }
            }
            if item != nil && item.screenshots != nil && screenshotsButton.state == NSOnState {
                var htmlString = "<html><body>"
                for url in item.screenshots.split() {
                    htmlString += "<img src=\"\(url)\" border=\"1\">"
                }
                htmlString += "</body></html>"
                updateCmdLine("screenshots of \(item.name)")
                webView.mainFrame.loadHTMLString(htmlString, baseURL: nil)
            } else {
                if page != webView.mainFrameURL {
                    webView.mainFrameURL = page
                } else {
                    updateCmdLine(page)
                }
            }
        } else {
            if item != nil {
                let cmd = (item.source.cmd as NSString).lastPathComponent
                if item.source.name == "Mac OS X" {
                    updateCmdLine("\(cmd) \(item.id)")
                } else {
                    updateCmdLine("\(cmd) \(item.name)")
                }
            }
            if selectedSegment == "Info" || selectedSegment == "Contents" || selectedSegment == "Spec" || selectedSegment == "Deps" {
                infoText.delegate = nil  // avoid textViewDidChangeSelection notification
                tabView.selectTabViewItemWithIdentifier("info")
                tabView.display()
                if item != nil {
                    info("")
                    if !statusField.stringValue.hasPrefix("Executing") {
                        status("Getting info...")
                    }
                    if selectedSegment == "Info" {
                        info(item.info)
                        infoText.checkTextInDocument(nil)

                    } else if selectedSegment == "Contents" {
                        let contents = item.contents
                        if contents == "" || contents.hasSuffix("not installed.\n") {
                            info("[Contents not available]")
                        } else {
                            info("[Click on a path to open in Finder]\n\(contents)\nUninstall command:\n\((item as! GPackage).uninstallCmd)")
                        }

                    } else if selectedSegment == "Spec" {
                        info(item.cat)
                        infoText.checkTextInDocument(nil)

                    } else if selectedSegment == "Deps" {
                        tableProgressIndicator.startAnimation(self)
                        status("Computing dependencies...")
                        var deps = item.deps
                        let dependents = item.dependents
                        if deps == "" && dependents == "" {
                            info("[No dependencies]")
                        } else {
                            deps = "[Click on a dependency to search for it]\n\(deps)"
                            if dependents != "" {
                                info("\(deps)\nDependents:\n\(dependents)")
                            } else {
                                info(deps)
                            }
                        }
                        tableProgressIndicator.stopAnimation(self)
                    }
                }
                infoText.delegate = self
                if !statusField.stringValue.hasPrefix("Executing") {
                    status("OK.")
                }
            } else if selectedSegment == "Shell" {
                tabView.selectTabViewItemWithIdentifier("log")
            }
            tabView.display()
        }
    }

    func updateCmdLine(cmd: String) {
        cmdline.stringValue = cmd
        cmdline.display()
    }

    func clear(sender: AnyObject) {
        logText.string = ""
    }


    func webView(sender: WebView, didStartProvisionalLoadForFrame: WebFrame) {
        var url = webView.mainFrameURL
        if url.hasPrefix("about:") {
            url = cmdline.stringValue
        }
        updateCmdLine("Loading \(url)...")
        if self.ready && !statusField.stringValue.hasPrefix("Executing") {
            status("Loading \(url)...")
        }
    }

    func webView(sender: WebView, didFinishLoadForFrame: WebFrame) {
        let cmdlineString = cmdline.stringValue
        if cmdlineString.hasPrefix("Loading") {
            updateCmdLine(cmdlineString.substring(8, cmdlineString.length - 11))
            if self.ready && !statusField.stringValue.hasPrefix("Executing") {
                status("OK.")
            }
        } else {
            updateCmdLine(webView.mainFrameURL)
        }
    }

    func webView(sender: WebView, didFailProvisionalLoadWithError: NSError, forFrame: WebFrame) {
        let cmdlineString = cmdline.stringValue
        if cmdlineString.hasPrefix("Loading") {
            updateCmdLine("Failed: \(cmdlineString.substring(8, cmdlineString.length - 11))")
            if self.ready && !statusField.stringValue.hasPrefix("Executing") {
                status("OK.")
            }
        } else {
            updateCmdLine(webView.mainFrameURL)
        }
    }

    func updateScrape(scrape: GScrape) {
        segmentedControl.selectedSegment = 1
        selectedSegment = "Home"
        tabView.display()
        if self.ready && !statusField.stringValue.hasPrefix("Executing") {
            status("Scraping \(scrape.name)...")
        }
        let scrapesCount: Int = (defaults["ScrapesCount"] as! NSNumber).integerValue
        let pagesToScrape = Int(ceil(Double(scrapesCount) / Double(scrape.itemsPerPage)))
        for var i = 1; i <= pagesToScrape; ++i {
            scrape.refresh()
            itemsController.addObjects(scrape.items)
            itemsTable.display()
            if i != pagesToScrape {
                scrape.pageNumber++
            }
        }
        if itemsController.selectionIndex == NSNotFound {
            itemsController.setSelectionIndex(0)
        }
        window.makeFirstResponder(itemsTable)
        itemsTable.display()
        screenshotsButton.hidden = false
        moreButton.hidden = false
        updateTabView(itemsController.selectedObjects[0] as! GItem)
        tableProgressIndicator.stopAnimation(self)
        if !statusField.stringValue.hasPrefix("Executing") {
            status("OK.")
        }
    }


    @IBAction func moreScrapes(sender: AnyObject) {
        tableProgressIndicator.startAnimation(self)
        let scrape = sourcesController.selectedObjects[0] as! GScrape
        scrape.pageNumber += 1
        updateScrape(scrape)
        itemsController.rearrangeObjects()
        tableProgressIndicator.stopAnimation(self)
    }

    @IBAction func toggleScreenshots(sender: AnyObject) {
        let selectedItems = itemsController.selectedObjects
        var item: GItem? = nil
        if selectedItems.count > 0 {
            tableProgressIndicator.startAnimation(self)
            item = selectedItems[0] as? GItem
            updateTabView(item)
            tableProgressIndicator.stopAnimation(self)
        }
    }

    override func controlTextDidBeginEditing(aNotification: NSNotification) {
    }

    func textViewDidChangeSelection(aNotification: NSNotification) {
        let selectedRange = infoText.selectedRange as NSRange
        let storageString = infoText.textStorage!.string as NSString
        let line = storageString.substringWithRange(storageString.paragraphRangeForRange(selectedRange))

        if selectedSegment == "Contents" {
            var file: String = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            // TODO detect types
            if file.contains(" -> ") { // Homebrew Casks
                file = file.split(" -> ")[1].stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "'"))
            }
            file = (file.split(" (")[0] as NSString).stringByExpandingTildeInPath
            if file.hasSuffix(".nib") {
                execute("/usr/bin/plutil -convert xml1 -o - \(file)")
            } else {
                NSWorkspace.sharedWorkspace().openFile(file)
            }

        } else if selectedSegment == "Deps" {
            let dep = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            let selectedItems = itemsController.selectedObjects
            var item: GItem! = nil
            if selectedItems.count > 0 {
                item = selectedItems[0] as? GItem
                if let pkg = item.system[dep] {
                    searchField.stringValue = dep
                    searchField.performClick(self)
                    itemsController.setSelectedObjects([pkg])
                    itemsTable.scrollRowToVisible(itemsController.selectionIndex)
                    window.makeFirstResponder(itemsTable)
                }
            }
        }
    }

    func textView(textView: NSTextView, clickedOnLink link: AnyObject, atIndex charIndex: Int) -> Bool {
        let url = link as! NSURL
        let urlString = url.absoluteString
        if urlString.hasPrefix("http") {
            cmdline.stringValue = urlString
            segmentedControl.selectedSegment = 1
            selectedSegment = "Home"
            updateTabView(nil)
            return true
        } else {
            return false
        }
    }

    @IBAction func executeCmdLine(sender: AnyObject) {
        let selectedItems = itemsController.selectedObjects
        var item: GItem? = nil
        if selectedItems.count > 0 {
            item = selectedItems[0] as? GItem
        }
        var output = ""
        let input: String! = cmdline.stringValue
        if input == nil {
            return
        }
        var tokens = input.split()
        var cmd = tokens[0]
        if cmd.hasPrefix("http") || cmd.hasPrefix("www") { // TODO
            if cmd.hasPrefix("www") {
                updateCmdLine("http://\(cmd)")
            }
            segmentedControl.selectedSegment = 1
            selectedSegment = "Home"
            updateTabView(nil)
        } else {
            segmentedControl.selectedSegment = -1
            updateTabView(item)
            if cmd == "sudo" {
                sudo(input.substringFromIndex(5))
            } else {
                for system in systems {
                    if system.cmd.hasSuffix(cmd) {
                        cmd = system.cmd
                        tokens[0] = cmd
                        break
                    }
                }
                if !cmd.hasPrefix("/") {
                    output = agent.output("/bin/bash -l -c which__\(cmd)")
                    if output.length != 0 {
                        tokens[0] = output.substringToIndex(output.length - 1)
                        // } else // TODO:show stderr
                    }
                }
                cmd = tokens.join()
                log("😺===> \(cmd)\n")
                status("Executing '\(cmd)'...")
                cmd = cmd.replace(" ", "__")
                cmd = "/bin/bash -l -c \(cmd)"
                output = agent.output(cmd)
                if self.ready {
                    status("OK.")
                }
                log(output)
            }
        }
    }


    @IBAction func executeCommandsMenu(sender: NSPopUpButton) {
        let selectedItems = itemsController.selectedObjects
        var item: GItem! = nil
        if selectedItems.count > 0 {
            item = selectedItems[0] as! GItem
        }
        let title = sender.titleOfSelectedItem!
        if let system = item.system {
            let idx = system.availableCommands().map {$0[0]}.indexOf(title)
            var command = system.availableCommands()[idx!][1]
            command = command.replace("CMD", (system.cmd as NSString).lastPathComponent)
            updateCmdLine(command)
            executeCmdLine(sender)
        }
    }


    func execute(cmd: String, baton: String) {
        let briefCmd = cmd.split(" ; ").filter { !($0.hasPrefix("sudo mv")) }.join(" ; ")
        status("Executing '\(briefCmd)' in the shell...")
        log("😺===> \(briefCmd)\n")
        var command: String
        if baton == "relaunch" {
            self.ready = false
            command = "\(cmd) ; osascript -e 'tell app \"Guigna\"' -e 'quit' -e 'end tell' &>/dev/null ; osascript -e 'tell app \"Guigna\"' -e 'ignoring application responses' -e 'activate' -e 'end ignoring' -e 'end tell' &>/dev/null"
        } else {
            command = "\(cmd) ; guigna --baton \(baton)"
        }

        if adminPassword != nil {
            command = command.replace("sudo", "echo \"\(adminPassword!)\" | sudo -S")
        }
        raiseShell(self)
        terminal.doScript(command, `in`:self.shell)

    }

    func execute(cmd: String) {
        execute(cmd, baton:"output")
    }

    func sudo(cmd: String, baton: String) {
        let command = "sudo \(cmd)"
        execute(command, baton: baton)
    }

    func sudo(cmd: String) {
        sudo(cmd, baton: "output")
    }

    func executeAsRoot(var cmd: String) {
        cmd = cmd.replace("\"", "\\\"")
        let command = "osascript -e 'do shell script \"\(cmd)\" with administrator privileges'"
        system(command)
    }

    func minuteCheck(timer: NSTimer) {
        if shellWindow != nil && (shellWindow.valueForKey("name") as! NSString).containsString("sudo") {
            if NSApplication.sharedApplication().active {
                raiseShell(self)
            }
            NSApplication.sharedApplication().requestUserAttention(.CriticalRequest)
        }
    }


    func menuNeedsUpdate(menu: NSMenu) {
        let title = menu.title

        if title == "ItemsColumnsMenu" {
            for menuItem in menu.itemArray {
                let column = menuItem.representedObject as! NSTableColumn
                menuItem.state = column.hidden ? NSOffState : NSOnState
            }
        } else {
            let selectedObjects = itemsController.selectedObjects as NSArray
            var selectedItems = selectedObjects.copy() as! [GItem]
            let clickedRow = itemsTable.clickedRow
            if clickedRow != -1 {
                let arrangedObjects = itemsController.arrangedObjects as! NSArray
                selectedItems.append(arrangedObjects[itemsTable.clickedRow] as! GItem)
            }

            if title == "Mark" { // TODO: Disable marks based on status
                tableProgressIndicator.startAnimation(self)
                status("Analyzing selected items...")
                let installMenu = menu.itemWithTitle("Install")!
                if installMenu.hasSubmenu {
                    installMenu.submenu!.removeAllItems()
                    installMenu.submenu = nil
                }
                // TODO: Analyze multiple items
                if selectedItems.count == 1 {
                    for item in [selectedItems[0]] {
                        if item.system == nil {
                            continue
                        }
                        var availableOptions = [String]()
                        if let itemAvailableOptions = item.system.options(item as! GPackage) {
                            availableOptions += itemAvailableOptions.split()
                        }
                        var markedOptions = [String]()
                        if let itemMarkedOptions = (item as! GPackage).markedOptions {
                            markedOptions += itemMarkedOptions.split()
                        }
                        var currentOptions = [String]()
                        if let itemOptions = (item as! GPackage).options {
                            currentOptions += itemOptions.split()
                        }
                        if markedOptions.count == 0 && currentOptions.count > 0 {
                            markedOptions += currentOptions
                            (item as! GPackage).markedOptions = markedOptions.join()
                        }
                        if availableOptions.count > 0 && availableOptions[0] != "" {
                            let optionsMenu = NSMenu(title: "Options")
                            for availableOption in availableOptions {
                                optionsMenu.addItemWithTitle(availableOption, action: "mark:", keyEquivalent: "")
                                var options = Set(markedOptions)
                                options.unionInPlace(currentOptions)
                                for option in options {
                                    if option == availableOption {
                                        optionsMenu.itemWithTitle(availableOption)?.state = NSOnState
                                    }
                                }
                            }
                            installMenu.submenu = optionsMenu
                        }
                    }
                }
                tableProgressIndicator.stopAnimation(self)
                if !statusField.stringValue.hasPrefix("Executing") {
                    status("OK.")
                }

            } else if title == "Commands" {
                while commandsPopUp.numberOfItems > 1 {
                    commandsPopUp.removeItemAtIndex(1)
                }
                if selectedItems.count == 0 {
                    commandsPopUp.addItemWithTitle("[no package selected]")
                } else {
                    let item = selectedItems[0] // TODO
                    if item.system != nil {
                        for commandArray in item.system.availableCommands() {
                            commandsPopUp.addItemWithTitle(commandArray[0])
                        }
                    }
                }
            }
        }
    }


    @IBAction func marks(sender: AnyObject) {
        // TODO
        showMarkMenu(self)
    }

    @IBAction func showMarkMenu(sender: AnyObject) {
        NSMenu.popUpContextMenu(markMenu, withEvent: NSApp.currentEvent!, forView: itemsTable)
    }

    @IBAction func mark(sender: NSMenuItem) {
        let selectedObjects = itemsController.selectedObjects as NSArray
        var selectedItems = selectedObjects.copy() as! [GItem]
        if itemsTable.clickedRow != -1 {
            let arrangedObjects = itemsController.arrangedObjects as! NSArray
            selectedItems.append(arrangedObjects[itemsTable.clickedRow] as! GItem)
        }
        var title: String
        var mark: GMark = .NoMark
        for item in selectedItems {
            title = sender.title

            if title == "Install" {
                if (item.source is GScrape) && item.URL != nil {
                    NSWorkspace.sharedWorkspace().openURL(NSURL(string: item.URL)!)
                    continue
                }
                mark = .Install

            } else if title == "Uninstall" {
                mark = .Uninstall

            } else if title == "Deactivate" {
                mark = .Deactivate

            } else if title == "Upgrade" {
                mark = .Upgrade

            } else if title == "Fetch" {
                if (item.source is GScrape) && item.URL != nil {
                    NSWorkspace.sharedWorkspace().openURL(NSURL(string: item.URL)!)
                    continue
                }
                mark = .Fetch

            } else if title == "Clean" {
                mark = .Clean

            } else if title == "Unmark" {
                mark = .NoMark
                if item is GPackage {
                    (item as! GPackage).markedOptions = nil
                    packagesIndex[(item as! GPackage).key()]!.markedOptions = nil
                }
            } else { // variant/option submenu selected
                var markedOptions = [String]()
                if (item as! GPackage).markedOptions != nil {
                    markedOptions += (item as! GPackage).markedOptions.split()
                }
                if sender.state == NSOffState {
                    markedOptions.append(title)
                } else {
                    markedOptions.removeAtIndex(markedOptions.indexOf(title)!)
                }
                var options: String! = nil
                if markedOptions.count > 0 {
                    options = markedOptions.join()
                }
                (item as! GPackage).markedOptions = options
                packagesIndex[(item as! GPackage).key()]!.markedOptions = options
                mark = .Install
            }

            if title == "Unmark" {
                if item.mark != .NoMark {
                    marksCount--
                }
            } else {
                if item.mark == .NoMark {
                    marksCount++
                }
            }

            item.mark = mark
            let systemName = item.system.name
            var package: GPackage!

            if item.status == .Inactive || systemName == "Mac OS X" || systemName == "iTunes" {
                package = allPackages.filter { $0.name == item.name && $0.installed != nil && $0.installed == item.installed }[0]
            } else {
                package = packagesIndex[(item as! GPackage).key()]!
                package.version = item.version
                package.options = (item as! GPackage).options
            }
            package.mark = mark
        }
        updateMarkedSource()
    }

    func updateMarkedSource() {
        sourcesOutline.setDelegate(nil)
        let sourcesContent = sourcesController.content as! NSArray
        let statusSource = sourcesContent[2] as! GSource
        let statuses = statusSource.categories! as! [GSource]
        let statusesMutableArray = statusSource.mutableArrayValueForKey("categories")
        var currentMarked = statuses.filter { $0.name.hasPrefix("marked") }
        if currentMarked.count > 0 && marksCount == 0 {
            statusesMutableArray.removeObject(currentMarked[0])
        }
        if marksCount > 0 {
            let name = "marked (\(marksCount))"
            if currentMarked.count == 0 {
                let markedSource = GSource(name: name)
                statusesMutableArray.addObject(markedSource)
            } else {
                (currentMarked[0] as GSource).name = name
            }
            NSApplication.sharedApplication().dockTile.badgeLabel = "\(marksCount)"
        } else {
            NSApplication.sharedApplication().dockTile.badgeLabel = nil
        }
        sourcesOutline.setDelegate(self)
        applyButton.enabled = (marksCount > 0)
    }


    @IBAction func apply(sender: AnyObject) {
        self.ready = false
        markedItems = allPackages.filter { $0.mark != .NoMark } as [GItem]
        marksCount = markedItems.count
        if marksCount == 0 {
            return
        }
        applyButton.enabled = false
        stopButton.enabled = true
        itemsController.setSelectedObjects([])
        segmentedControl.selectedSegment = -1
        selectedSegment = "Shell"
        updateTabView(nil)
        var tasks = [String]()
        let markedSystems = NSMutableSet()
        for item in markedItems as! [GPackage] {
            markedSystems.addObject(item.system)
        }

        // workaround since an immutable array is necessary as a Dictionary Optional
        var systemsDict = [String: [GPackage]]()
        for system in markedSystems.allObjects as! [GSystem] {
            systemsDict[system.name] = [GPackage]()
        }
        for item in markedItems as! [GPackage] {
            systemsDict[item.system.name]?.append(item)
        }

        let prefixes = ["/opt/local", "/usr/local", "/sw", "/usr/pkg", "/opt/pkg"]
        var detectedPrefixes = [String]()
        for prefix in prefixes {
            if prefix.exists {
                detectedPrefixes.append(prefix)
            }
        }
        for system in systems {
            if let idx = detectedPrefixes.indexOf(system.prefix) {
                detectedPrefixes.removeAtIndex(idx)
            }
        }
        var mark: GMark
        // let markNames = ["None", "Install", "Uninstall", "Deactivate", "Upgrade", "Fetch", "Clean"]
        // var markName: String
        for system in markedSystems.allObjects as! [GSystem] {
            var systemTasks = [String]()
            var systemCommands = [String]()
            var command: String!
            var hidesOthers = false
            for item in systemsDict[system.name]! {
                mark = item.mark
                // markName = markNames[Int(mark.rawValue)]
                command = nil
                hidesOthers = false

                if mark == .Install {
                    command = item.installCmd

                    if item.system.name != "Homebrew Casks" && item.system.name != "Rudix" {
                        hidesOthers = true
                    }

                } else if mark == .Uninstall {
                    command = item.uninstallCmd

                } else if mark == .Deactivate {
                    command = item.deactivateCmd

                } else if mark == .Upgrade {
                    command = item.upgradeCmd
                    hidesOthers = true

                } else if mark == .Fetch {
                    command = item.fetchCmd

                } else if mark == .Clean {
                    command = item.cleanCmd
                }

                if command != nil {
                    if defaults["DebugMode"] == true {
                        command = item.system.verbosifiedCmd(command)
                    }
                    systemCommands.append(command)
                }
            }

            if hidesOthers && (systems.count > 1 || detectedPrefixes.count > 0) {
                for otherSystem in systems {
                    if otherSystem === system {
                        continue
                    }
                    if otherSystem.hideCmd != nil
                        && otherSystem.hideCmd != system.hideCmd
                        && systemTasks.indexOf(otherSystem.hideCmd) == nil
                        && otherSystem.prefix.exists {
                            tasks.append(otherSystem.hideCmd)
                            systemTasks.append(otherSystem.hideCmd)
                            // TODO: set GOnlineMode
                    }
                }
                for prefix in detectedPrefixes {
                    if prefix != "/usr/local" {
                        tasks.append("sudo mv \(prefix) \(prefix)_off")
                    } else {
                        tasks.append("for dir in bin etc include lib opt share ; do sudo mv \(prefix)/\"$dir\"{,_off} ; done")
                    }
                }
            }
            tasks += systemCommands
            if hidesOthers && (systems.count > 1 || detectedPrefixes.count > 0) {
                for otherSystem in systems {
                    if otherSystem === system {
                        continue
                    }
                    if otherSystem.hideCmd != nil
                        && otherSystem.hideCmd != system.hideCmd
                        && systemTasks.indexOf(otherSystem.unhideCmd) == nil
                        && otherSystem.prefix.exists {
                            tasks.append(otherSystem.unhideCmd)
                            systemTasks.append(otherSystem.unhideCmd)
                    }
                }
                for prefix in detectedPrefixes {
                    if prefix != "/usr/local" {
                        tasks.append("sudo mv \(prefix)_off \(prefix)")
                    } else {
                        tasks.append("for dir in bin etc include lib opt share ; do sudo mv \(prefix)/\"$dir\"{_off,} ; done")
                    }
                }
            }
        }
        execute(tasks.join(" ; "))

    }


    func raiseBrowser(sender: AnyObject) {
        let selectedItems = itemsController.selectedObjects
        var item: GItem? = nil
        if selectedItems.count > 0 {
            item = selectedItems[0] as? GItem
        }
        var url = cmdline.stringValue
        if item == nil && !url.hasPrefix("http") {
            url = "http://github.com/gui-dos/Guigna/"
        }
        if url.hasPrefix("Loading") {
            url = url.substring(8, url.length - 11)
            updateCmdLine(url)
            if !statusField.stringValue.hasPrefix("Executing") {
                status("Launched in browser: \(url)")
            }
        } else if !url.hasPrefix("http") {
            if item?.homepage != nil {
                url = item!.homepage
            } else {
                url = item!.home
            }
        }
        browser.activate()
        let windows = browser.valueForKey("windows") as! NSMutableArray
        var firstWindow = windows[0] as! NSObject
        if windows.count == 0 {
            let documentClass: NSObject.Type = browser.classForScriptingClass("document") as! NSObject.Type
            windows.addObject(documentClass.init())
        } else {
            var tabs = firstWindow.valueForKey("tabs") as! NSMutableArray
            let tabClass: NSObject.Type = browser.classForScriptingClass("tab") as! NSObject.Type
            tabs.addObject(tabClass.init())
            tabs = firstWindow.valueForKey("tabs") as! NSMutableArray
            let lastTab = tabs.objectAtIndex(tabs.count-1) as! NSObject
            firstWindow.setValue(lastTab, forKey: "currentTab")
        }
        firstWindow = (browser.valueForKey("windows") as! [NSObject])[0]
        firstWindow.valueForKey("document")!.setValue(NSURL(string: url)!, forKey: "URL")
    }

    func raiseShell(sender: AnyObject) {
        for window in terminal.valueForKey("windows") as! [NSObject] {
            if !(window.valueForKey("name") as! NSString).containsString("Guigna ") {
                window.setValue(false, forKey: "visible")
            }
        }
        terminal.activate()
        var frame: NSRect = tabView.frame
        frame.size.width += 0
        frame.size.height -= 3
        frame.origin.x = window.frame.origin.x + sourcesOutline.superview!.frame.size.width + 1
        frame.origin.y = window.frame.origin.y + 22
        for window in terminal.valueForKey("windows") as! [NSObject] {
            if (window.valueForKey("name") as! NSString).containsString("Guigna ") {
                shellWindow = window
            }
        }
        shellWindow.setValue(NSValue(rect: frame), forKey: "frame")
        for window in terminal.valueForKey("windows") as! [NSObject] {
            if !(window.valueForKey("name") as! NSString).containsString("Guigna ") {
                window.setValue(false, forKey: "frontmost")
            }
        }
    }

    func open(sender: AnyObject) {
        NSApp.activateIgnoringOtherApps(true)
        window.makeKeyAndOrderFront(nil)
        raiseShell(self)
    }

    @IBAction func options(sender: AnyObject) {
        window.beginSheet(optionsPanel) {
            if $0 == NSModalResponseStop {
                // TODO
            }
        }
    }

    @IBAction func closeOptions(sender: AnyObject) {
        self.window.endSheet(self.optionsPanel)
        if self.ready {
            syncButton.enabled = true
        }
    }


    func optionsStatus(var msg: String) {
        if msg.hasSuffix("...") {
            optionsProgressIndicator.startAnimation(self)
            if optionsStatusField.stringValue.hasPrefix("Executing") {
                msg = "\(optionsStatusField.stringValue) \(msg)"
            }
        } else {
            optionsProgressIndicator.stopAnimation(self)
        }
        status(msg)
        if msg == "OK." {
            msg = ""
        }
        optionsStatusField.stringValue = msg
        optionsStatusField.display()
    }


    @IBAction func preferences(sender: AnyObject) {
        self.ready = false
        // optionsPanel.display()
        if sender is NSSegmentedControl {
            let theme = (sender as! NSSegmentedControl).labelForSegment((sender as! NSSegmentedControl).selectedSegment)!
            applyTheme(theme)

        } else {
            if sender is NSButton {
                let title = (sender as! NSButton).title
                let state = (sender as! NSButton).state
                var system: GSystem!
                var command = "command"
                var addedSystems = [GSystem]()

                if state == NSOnState {
                    optionsStatus("Adding \(title)...")
                    agent.output("/bin/echo") // workaround for updating status in El Capitan

                    if title == "Homebrew" {
                        command = "/usr/local/bin/brew"
                        if command.exists {
                            system = Homebrew(agent: agent)
                            addedSystems.append(system)
                            if "/usr/local/Library/Taps/caskroom/homebrew-cask/cmd/brew-cask.rb".exists {
                                system = HomebrewCasks(agent: agent)
                                addedSystems.append(system)
                            }
                        }

                    } else if title == "MacPorts" {
                        command = "/opt/local/bin/port"
                        system = MacPorts(agent: agent)
                        let escapedAppDir = APPDIR.replace(" ","__")
                        if !command.exists {
                            agent.output("/usr/bin/rsync -rtzv rsync://rsync.macports.org/release/tarballs/PortIndex_darwin_15_i386/PortIndex \(escapedAppDir)/MacPorts/PortIndex")
                            system.mode = .Online
                        }
                        addedSystems.append(system)

                    } else if title == "Fink" {
                        command = "/sw/bin/fink"
                        system = Fink(agent: agent)
                        system.mode = command.exists ? .Offline : .Online
                        addedSystems.append(system)

                    } else if title == "pkgsrc" {
                        command = "/usr/pkg/sbin/pkg_info"
                        system = Pkgsrc(agent: agent)
                        system.mode = command.exists ? .Offline : .Online
                        addedSystems.append(system)

                    } else if title == "FreeBSD" {
                        system = FreeBSD(agent: agent)
                        system.mode = .Online
                        addedSystems.append(system)


                    } else if title == "Rudix" {
                        command = "/usr/local/bin/rudix"
                        system = Rudix(agent: agent)
                        system.mode = command.exists ? .Offline : .Online
                        if system.mode == .Offline { // FIXME: manifest is not available anymore
                            addedSystems.append(system)
                        }

                    } else if title == "iTunes" {
                        system = ITunes(agent: agent)
                        addedSystems.append(system)
                    }

                    if addedSystems.count > 0 {
                        for system in addedSystems {
                            addSystem(system)
                        }
                        sourcesOutline.reloadData()
                        sourcesOutline.display()
                        itemsController.sortDescriptors = [NSSortDescriptor(key: "status", ascending: false)]
                        optionsStatus("OK.")
                    } else {
                        optionsStatus("\(title)'s \(command) not detected.")
                    }

                } else {
                    removeSystems(named: title)
                    optionsStatus("OK.")
                }
            }
        }
        self.ready = true
    }

    func addSystem(system: GSystem) {
        systems.append(system)
        let sourcesContent = self.sourcesController.content as! NSArray
        let systemsSource = sourcesContent[0] as! GSource
        let systemsArray = systemsSource.categories! as! [GSource]
        let systemsMutableArray = systemsSource.mutableArrayValueForKey("categories")
        let systemsCount = systemsArray.count
        systemsMutableArray.addObject(system)
        // selecting the new system avoids memory peak > 1.5 GB:
        sourcesController.setSelectionIndexPath(NSIndexPath(index: 0).indexPathByAddingIndex(systemsCount))
        sourcesOutline.reloadData()
        sourcesOutline.display()
        sourcesSelectionDidChange(systemsMutableArray[systemsCount])
        itemsController.addObjects(system.list())
        itemsTable.display()
        allPackages += system.items as! [GPackage]
        for (key, value) in system.index {
            packagesIndex[key] = value
        }
        // duplicate code from reloalAllPackages
        system.categories = []
        let categories = system.mutableArrayValueForKey("categories")
        for category in system.categoriesList() {
            let categorySource = GSource(name: category)
            if system.name == "Homebrew" {
                if category == "cask" {
                    continue
                }
                categorySource.homepage = system.logpage.replace("homebrew", "homebrew-" + category)
            }
            categories.addObject(categorySource)
        }
    }

    func removeSystems(named name: String) {
        optionsStatus("Removing \(name)...")
        agent.output("/bin/echo") // workaround for updating status in El Capitan
        let sourcesContent = self.sourcesController.content as! NSArray
        let systemsSource = sourcesContent[0] as! GSource
        let systemsArray = systemsSource.categories! as! [GSource]
        let systemsMutableArray = systemsSource.mutableArrayValueForKey("categories")
        let filtered = systemsArray.filter { $0.name.hasPrefix(name) }
        var status: GState = .Off
        if filtered.count > 0 {
            for source in filtered as! [GSystem] {
                status = source.status
                if status == .On {
                    itemsController.removeObjects(items.filter { $0.system.name == source.name })
                    allPackages = allPackages.filter { $0.system.name != source.name }
                    for pkg in source.items as! [GPackage] {
                        packagesIndex.removeValueForKey(pkg.key())
                    }
                    source.items.removeAll()
                    systemsMutableArray.removeObject(source)
                    systems.removeAtIndex(systems.indexOf(source)!)
                }
            }
        }
    }


    func applyTheme(theme: String) {
        if theme == "Retro" {
            window.backgroundColor = NSColor.greenColor()
            segmentedControl.superview!.wantsLayer = true
            segmentedControl.superview!.layer!.backgroundColor = NSColor.blackColor().CGColor
            itemsTable.backgroundColor = NSColor.blackColor()
            itemsTable.usesAlternatingRowBackgroundColors = false
            tableFont = NSFont(name: "Andale Mono", size: 11.0)
            tableTextColor = NSColor.greenColor()
            itemsTable.gridColor = NSColor.greenColor()
            itemsTable.gridStyleMask = .DashedHorizontalGridLineMask
            (sourcesOutline.superview!.superview! as! NSScrollView).borderType = .LineBorder
            sourcesOutline.backgroundColor = NSColor.blackColor()
            segmentedControl.segmentStyle = .SmallSquare
            commandsPopUp.bezelStyle = .SmallSquareBezelStyle
            (infoText.superview!.superview! as! NSScrollView).borderType = .LineBorder
            infoText.backgroundColor = NSColor.blackColor()
            infoText.textColor = NSColor.greenColor()
            var cyanLinkAttribute = linkTextAttributes
            cyanLinkAttribute[NSForegroundColorAttributeName] = NSColor.cyanColor()
            infoText.linkTextAttributes = cyanLinkAttribute
            (logText.superview!.superview! as! NSScrollView).borderType = .LineBorder
            logText.backgroundColor = NSColor.blueColor()
            logText.textColor = NSColor.whiteColor()
            logTextColor = NSColor.whiteColor()
            statusField.drawsBackground = true
            statusField.backgroundColor =  NSColor.greenColor()
            cmdline.backgroundColor = NSColor.blueColor()
            cmdline.textColor = NSColor.whiteColor()
            clearButton.bezelStyle = .SmallSquareBezelStyle
            screenshotsButton.bezelStyle = .SmallSquareBezelStyle
            moreButton.bezelStyle = .SmallSquareBezelStyle
            statsLabel.drawsBackground = true
            statsLabel.backgroundColor = NSColor.greenColor()
            shell.setValue(NSColor(calibratedRed: 0.0, green: 0.0, blue: 1.0, alpha: 1.0), forKey: "backgroundColor")
            shell.setValue(NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), forKey: "normalTextColor")

        } else { // Default theme
            window.backgroundColor = NSColor.windowBackgroundColor()
            segmentedControl.superview!.layer!.backgroundColor = NSColor.windowBackgroundColor().CGColor
            itemsTable.backgroundColor = NSColor.whiteColor()
            itemsTable.usesAlternatingRowBackgroundColors = true
            tableFont = NSFont.controlContentFontOfSize(NSFont.systemFontSizeForControlSize(.SmallControlSize))
            tableTextColor = NSColor.blackColor()
            itemsTable.gridStyleMask = .GridNone
            itemsTable.gridColor = NSColor.gridColor()
            (sourcesOutline.superview!.superview! as! NSScrollView).borderType = .GrooveBorder
            sourcesOutline.backgroundColor = sourceListBackgroundColor
            segmentedControl.segmentStyle = .Rounded
            commandsPopUp.bezelStyle = .RoundRectBezelStyle // TODO: Round in Mavericks
            (infoText.superview!.superview! as! NSScrollView).borderType = .GrooveBorder
            infoText.backgroundColor = NSColor(calibratedRed: 0.82290249429999995, green: 0.97448979589999996, blue: 0.67131519269999995, alpha: 1.0) // light green
            infoText.textColor = NSColor.blackColor()
            infoText.linkTextAttributes = linkTextAttributes
            (logText.superview!.superview! as! NSScrollView).borderType = .GrooveBorder
            logText.backgroundColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.8, alpha: 1.0) // lioght yellow
            logText.textColor = NSColor.blackColor()
            logTextColor = NSColor.blackColor()
            statusField.drawsBackground = false
            cmdline.backgroundColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.8, alpha: 1.0)
            cmdline.textColor = NSColor.blackColor()
            clearButton.bezelStyle = .TexturedRoundedBezelStyle // TODO
            screenshotsButton.bezelStyle = .TexturedRoundedBezelStyle
            moreButton.bezelStyle = .TexturedRoundedBezelStyle
            statsLabel.drawsBackground = false
            shell.setValue(NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.8, alpha: 1.0), forKey: "backgroundColor")
            shell.setValue(NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0), forKey: "normalTextColor")
        }
        defaults["Theme"] = theme
    }


    @IBAction func toolsAction(sender: AnyObject) {
        NSMenu.popUpContextMenu(toolsMenu, withEvent: NSApp.currentEvent!, forView: itemsTable)
    }

    @IBAction func tools(sender: NSMenuItem) {
        let title = sender.title

        if title == "Install pkgsrc" {
            execute(Pkgsrc.setupCmd, baton: "relaunch")

        } else if title == "Fetch pkgsrc and INDEX" {
            execute("cd ~/Library/Application\\ Support/Guigna/pkgsrc ; curl -L -O ftp://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/INDEX ; curl -L -O ftp://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc.tar.gz ; sudo tar -xvzf pkgsrc.tar.gz -C /usr", baton: "relaunch")

        } else if title == "Install pkgin" {
            execute(Pkgin.setupCmd, baton: "relaunch")

        } else if title == "Remove pkgsrc" {
            execute(Pkgsrc.removeCmd, baton: "relaunch")

        } else if title == "Fetch FreeBSD INDEX" {
            execute("cd ~/Library/Application\\ Support/Guigna/FreeBSD ; curl -L -O ftp://ftp.freebsd.org/pub/FreeBSD/ports/packages/INDEX", baton: "relaunch")

        } else if title == "Install Fink" {
            execute(Fink.setupCmd, baton: "relaunch")

        } else if title == "Remove Fink" {
            execute(Fink.removeCmd, baton: "relaunch")

        } else if title == "Install Homebrew" {
            execute(Homebrew.setupCmd, baton: "relaunch")

        } else if title == "Install Homebrew Cask" {
            execute(HomebrewCasks.setupCmd, baton: "relaunch")

        } else if title == "Remove Homebrew" {
            execute(Homebrew.removeCmd, baton: "relaunch")
            
        } else if title == "Fetch MacPorts PortIndex" {
            execute("cd ~/Library/Application\\ Support/Guigna/MacPorts ; /usr/bin/rsync -rtzv rsync://rsync.macports.org/release/tarballs/PortIndex_darwin_15_i386/PortIndex PortIndex", baton: "relaunch")
            
        } else if title == "Install Rudix" {
            execute(Rudix.setupCmd, baton: "relaunch")
            
        } else if title == "Remove Rudix" {
            execute(Rudix.removeCmd, baton: "relaunch")
            
        } else if title == "Reset Guigna" {
            execute("defaults delete name.soranzio.guido.Guigna ; defaults delete name.soranzio.guido.Guigna-Swift ; rm -r Library/Application\\ Support/Guigna ; rm -r Library/Preferences/name.soranzio.guido.Guigna* ; rm -r Library/Saved\\ Application\\ State/name.soranzio.guido.Guigna*", baton: "relaunch")
            
        } else {
            execute("echo TODO")
        }
        
    }
    
    @IBAction func search(sender: AnyObject) {
        window.makeFirstResponder(searchField)
    }
    
    @IBAction func showHelp(sender: AnyObject) {
        cmdline.stringValue = "http://github.com/gui-dos/Guigna/wiki/The-Guigna-Guide"
        segmentedControl.selectedSegment = 1
        selectedSegment = "Home"
        updateTabView(nil)
    }
    
    @IBAction func stop(sender: AnyObject) {
    }
    
    @IBAction func details(sender: AnyObject) {
    }
    
    
    // GAppDelegate protocol
    
    func addItem(item: GItem) {
        allPackages.append(item as! GPackage)
    }
    
    func removeItem(item: GItem) {
        // TODO: remove a package from allPackages: GPackage should implement Equatable
    }
    
    func removeItems(excludeElement: (GItem) -> Bool) {
        allPackages = allPackages.filter {!excludeElement($0)}
    }
    
}


// TODO

@objc(GDefaultsTransformer)
class GDefaultsTransformer: NSValueTransformer {
}
