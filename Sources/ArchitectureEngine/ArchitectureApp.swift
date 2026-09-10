import AppKit
import SwiftUI
import MetalKit

@main
enum ArchitectureMain {
    @MainActor static func main() {
        if CommandLine.arguments.count > 1, runCommandLine() { return }
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let delegate = ArchitectureApplicationDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class PresentationState: ObservableObject {
    @Published var chromeVisible = true
}

@MainActor
private final class ArchitectureApplicationDelegate: NSObject, NSApplicationDelegate {
    private let engine = EngineController()
    private let presentation = PresentationState()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 960),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "ATELIER / Willis Tower"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 960, height: 680)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.backgroundColor = NSColor(red: 0.055, green: 0.073, blue: 0.080, alpha: 1)
        let hosting = NSHostingView(rootView: ArchitectureWorkspace(engine: engine, presentation: presentation))
        // The window owns its dimensions. SwiftUI's ideal-size propagation can
        // otherwise turn the viewport's pixel dimensions into a window minimum.
        hosting.sizingOptions = []
        hosting.frame = NSRect(x: 0, y: 0, width: 1440, height: 960)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.setFrameAutosaveName("AtelierArchitectureWindow")
        // Also discard an oversized frame saved by an earlier hosting layout.
        window.setContentSize(NSSize(width: 1440, height: 960))
        if let screen = window.screen ?? NSScreen.main {
            var frame = window.frame
            frame.size.width = min(frame.width, screen.visibleFrame.width)
            frame.size.height = min(frame.height, screen.visibleFrame.height)
            window.setFrame(frame, display: false)
        }
        window.center()
        self.window = window
        installMenus()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func installMenus() {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Atelier")
        applicationMenu.addItem(withTitle: "About Atelier", action: #selector(showAbout), keyEquivalent: "").target = self
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit Atelier", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Reset View", action: #selector(resetView), keyEquivalent: "r").target = self
        viewMenu.addItem(withTitle: "Show / Hide Interface", action: #selector(toggleInterface), keyEquivalent: "h").target = self
        viewMenu.addItem(withTitle: "Keyboard Controls", action: #selector(toggleHelp), keyEquivalent: "/").target = self
        viewMenu.addItem(.separator())
        let fullscreen = viewMenu.addItem(withTitle: "Enter / Exit Full Screen (G)", action: #selector(toggleFullscreen), keyEquivalent: "f")
        fullscreen.keyEquivalentModifierMask = [.command, .control]
        fullscreen.target = self
        viewMenu.addItem(withTitle: "Next Location", action: #selector(toggleLocation), keyEquivalent: "l").target = self
        viewMenu.addItem(withTitle: "Start / Stop Chicago Demo", action: #selector(toggleChicagoDemo), keyEquivalent: "").target = self
        viewMenu.addItem(withTitle: "Show / Hide Chicago Navigation Map", action: #selector(toggleNavigationMap), keyEquivalent: "").target = self
        viewMenu.addItem(withTitle: "Enter / Exit Top-down Map Mode", action: #selector(toggleMapMode), keyEquivalent: "").target = self
        viewMenu.addItem(withTitle: "Point Normal Camera Straight Down (T)", action: #selector(pointCameraDown), keyEquivalent: "").target = self
        viewMenu.addItem(withTitle: "Toggle Ray Tracing", action: #selector(toggleRayTracing), keyEquivalent: "").target = self
        viewMenu.addItem(.separator())
        let screenshot = viewMenu.addItem(withTitle: "Save Render", action: #selector(capture), keyEquivalent: "s")
        screenshot.keyEquivalentModifierMask = [.command, .shift]
        screenshot.target = self
        viewItem.submenu = viewMenu
        main.addItem(viewItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApplication.shared.mainMenu = main
        NSApplication.shared.windowsMenu = windowMenu
    }

    @objc private func toggleFullscreen() { engine.toggleFullscreen() }
    @objc private func toggleLocation() { engine.toggleLocation() }
    @objc private func toggleChicagoDemo() { engine.toggleChicagoDemo() }
    @objc private func toggleNavigationMap() { engine.toggleNavigationMap() }
    @objc private func toggleMapMode() { engine.toggleMapMode() }
    @objc private func pointCameraDown() { engine.pointCameraDown() }
    @objc private func toggleRayTracing() { engine.toggleRayTracing() }
    @objc private func resetView() { engine.resetView() }
    @objc private func toggleInterface() { presentation.chromeVisible.toggle() }
    @objc private func toggleHelp() { engine.showHelp.toggle() }
    @objc private func capture() { engine.captureScreenshot() }
    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "ATELIER",
            .applicationVersion: "2.4.2 · Paris & Chicago",
            .credits: NSAttributedString(string: "A native Metal architectural observatory.\nParis · Chicago from Robie House to Wrigley Field.\nReference-informed architecture and mapped surroundings.")
        ])
    }
}

@MainActor
/// Menu tracking must not depend on the continuously published frame statistics
/// and playback timeline. Only selection/readiness changes update this control.
private struct RendererSelectionMenu: View, Equatable {
    let engine: EngineController
    let selection: ArchitectureRendererMode
    let isReady: Bool
    private let accent = Color(red: 0.84, green: 0.75, blue: 0.55)

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.engine === rhs.engine && lhs.selection == rhs.selection && lhs.isReady == rhs.isReady
    }

    var body: some View {
        Menu {
            // A Picker inside Menu creates a second native hover menu. Direct
            // actions keep every renderer selectable in the first open menu.
            ForEach(ArchitectureRendererMode.allCases) { mode in
                Button { engine.setRendererMode(mode) } label: {
                    if mode == selection { Label(mode.title, systemImage: "checkmark") }
                    else { Text(mode.title) }
                }
            }
            Divider()
            Button("Toggle ray tracing · R") { engine.toggleRayTracing() }
        } label: {
            HStack(spacing: 7) {
                Circle().fill(isReady ? accent : .gray).frame(width: 5, height: 5)
                Text(selection.title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.1)
            }.padding(.leading, 14).padding(.trailing, 9)
        }.menuStyle(.borderlessButton).fixedSize()
            .help("Choose renderer · R toggles the last ray tracer and Fast Raster")
            .accessibilityLabel("Renderer: \(selection.title)").disabled(!isReady)
    }
}

private struct ArchitectureWorkspace: View {
    @ObservedObject var engine: EngineController
    @ObservedObject var presentation: PresentationState
    @State private var settingsOpen = false
    @State private var notice: String?
    private let accent = Color(red: 0.84, green: 0.75, blue: 0.55)
    private var stop: TourStop { engine.stops[min(max(engine.currentStop, 0), engine.stops.count - 1)] }

    var body: some View {
        GeometryReader { geometry in
        ZStack {
            MetalArchitectureViewport(engine: engine, presentation: presentation)
                .ignoresSafeArea()
            if presentation.chromeVisible {
                LinearGradient(colors: [.black.opacity(0.40), .clear, .clear, .black.opacity(0.43)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea().allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        if engine.isMapMode { mapIdentity } else { identity }
                        Spacer(minLength: 30)
                        VStack(alignment: .trailing, spacing: 16) {
                            toolbar
                            if engine.statsVisible {
                                if geometry.size.height >= 790 && !(engine.location.world == "chicago" && engine.navigationMapVisible) { performancePanel }
                                else { compactPerformancePanel }
                            }
                            if engine.location.world == "chicago" {
                                navigationMap(in:geometry.size)
                            }
                        }
                    }
                    Spacer(minLength: 20)
                    if engine.isMapMode { mapModePanel } else { tourPanel(compact:geometry.size.height<850) }
                }
                .padding(.horizontal, 38)
                .padding(.top, geometry.size.height<800 ? 30:50)
                .padding(.bottom, geometry.size.height<800 ? 20:30)
                .transition(.opacity)
            } else {
                VStack {
                    if engine.location.world == "chicago" {
                        HStack { Spacer(); navigationMap(in:geometry.size) }
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        if engine.isMapMode {
                            Button("Exit map mode · B") { engine.toggleMapMode() }
                                .font(.system(size:11,weight:.medium)).buttonStyle(.plain).padding(12).glassPanel(radius:10)
                        }
                        Button { presentation.chromeVisible = true } label: {
                            Label("Show interface · H", systemImage: "rectangle.on.rectangle")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 13).padding(.vertical, 9)
                        }.buttonStyle(.plain).glassPanel(radius: 10)
                    }
                }.padding(25)
            }
            if !engine.isReady { loadingPanel }
            if engine.showHelp { helpPanel }
            if let notice {
                VStack {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                        Text(notice).font(.system(size: 11))
                    }.padding(.horizontal, 17).padding(.vertical, 12).glassPanel(radius: 12)
                    Spacer()
                }.padding(.top, 26).allowsHitTesting(false)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .preferredColorScheme(.dark)
        .foregroundStyle(Color.white.opacity(0.94))
        .animation(.easeInOut(duration: 0.22), value: presentation.chromeVisible)
        .animation(.easeInOut(duration: 0.18), value: engine.showHelp)
        .onChange(of: engine.status) { _, message in
            guard engine.isReady, message.hasPrefix("Saved") else { return }
            notice = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if notice == message { notice = nil }
            }
        }
        .alert("Render interrupted", isPresented: Binding(get: { engine.isReady && engine.errorMessage != nil }, set: { if !$0 { engine.errorMessage = nil } })) {
            Button("OK") { engine.errorMessage = nil }
        } message: { Text(engine.errorMessage ?? "") }
        }
    }

    private func navigationMap(in viewport: CGSize) -> some View {
        ChicagoNavigationMap(camera:engine.mapCamera,isVisible:$engine.navigationMapVisible,size:$engine.navigationMapSize,
            maximumHeight:min(410,viewport.height*0.45),maximumWidth:min(430,viewport.width*0.45),
            onNavigate:engine.navigateCity,onLandmarkNavigate:engine.navigateCity,onPan:engine.panCityMap)
            .id(engine.mapSelectionRevision)
    }
    private var mapIdentity: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("ATELIER  /  CHICAGO").font(.system(size:11,weight:.semibold)).tracking(3).foregroundStyle(accent)
            Text("Map mode").font(.system(size:42,design:.serif))
            Text("NORTH UP  ·  WASD OR DRAG TO PAN  ·  SHIFT ×3").font(.system(size:10,weight:.medium)).tracking(2).foregroundStyle(.white.opacity(0.7))
            if let focused=engine.focusedObjectName {
                Button { engine.clearObjectFocus() } label: { Label("Focus: \(focused)",systemImage:"xmark.circle") }
                    .buttonStyle(.plain).font(.system(size:11)).foregroundStyle(accent).accessibilityLabel("Clear object focus")
            }
            Button { engine.toggleMapMode() } label: { Label("Return to 3D view · B",systemImage:"cube") }
                .buttonStyle(.plain).font(.system(size:12,weight:.medium)).padding(12).glassPanel(radius:9)
                .accessibilityLabel("Exit map mode")
        }
    }
    private var mapModePanel: some View {
        HStack(spacing:16) {
            Label("N",systemImage:"arrow.up").font(.system(size:12,weight:.semibold)).foregroundStyle(accent)
            Text("Drag to pan · Pinch to zoom").font(.system(size:12))
            Spacer()
            Text(engine.mapViewSpan>=1000 ? String(format:"%.1f km N–S",engine.mapViewSpan/1000):String(format:"%.0f m N–S",engine.mapViewSpan))
                .font(.system(size:11,design:.monospaced)).foregroundStyle(.white.opacity(0.6))
            Button { engine.zoomMap(false) } label: { Image(systemName:"minus.magnifyingglass") }
                .accessibilityLabel("Zoom city map out")
            Button { engine.zoomMap(true) } label: { Image(systemName:"plus.magnifyingglass") }
                .accessibilityLabel("Zoom city map in")
        }.buttonStyle(.plain).padding(18).glassPanel(radius:12)
    }
    private var identity: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 14) {
                Text("ATELIER").font(.system(size: 13, weight: .semibold)).tracking(5)
                Rectangle().fill(accent.opacity(0.7)).frame(width: 25, height: 1)
                Text("ARCHITECTURE  /  \(engine.location.number)").font(.system(size: 9, weight: .medium)).tracking(2.0).foregroundStyle(accent)
            }
            Text(engine.location.name).font(.system(size: 44, weight: .regular, design: .serif)).tracking(-1.1).lineLimit(1).minimumScaleFactor(0.6)
            Text(engine.location.subtitle).font(.system(size: 10, weight: .medium)).tracking(2.4)
                .foregroundStyle(.white.opacity(0.68))
            Picker("Location", selection: Binding(get: { engine.location }, set: { engine.selectLocation($0) })) {
                ForEach(ArchitectureLocation.allCases) { location in
                    Text("\(location.shortName) · \(location.name)").tag(location)
                }
            }.pickerStyle(.menu).labelsHidden().frame(width: 280, alignment: .leading)
                .help("Change the architectural location · L")
            HStack(spacing: 10) {
                Button { engine.toggleChicagoDemo() } label: {
                    Label(engine.chicagoDemoActive ? "Stop Chicago Demo" : "Chicago Demo", systemImage: engine.chicagoDemoActive ? "stop.circle" : "play.rectangle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(engine.chicagoDemoActive ? accent : .white.opacity(0.9))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }.buttonStyle(.plain).glassPanel(radius: 8)
                    .help("Start at a random Chicago view, then play all \(WalkthroughPlayback.chicagoDemoRouteCount) routes in order · C. Space pauses or resumes.")
                    .disabled(!engine.isReady)
                if engine.chicagoDemoActive {
                    Text(engine.chicagoDemoTitle).font(.system(size: 10)).foregroundStyle(accent)
                        .lineLimit(2).frame(maxWidth: 215, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 8).glassPanel(radius: 8)
                    iconButton("chevron.up", help: "Previous Chicago demo view · ↑ · crosses location boundaries") { engine.cycleView(-1) }
                        .glassPanel(radius: 8)
                    iconButton("chevron.down", help: "Next Chicago demo view · ↓ · crosses location boundaries") { engine.cycleView(1) }
                        .glassPanel(radius: 8)
                }
            }
            if engine.location.world == "chicago" {
                Menu {
                    Button("Willis → Park → Art Institute") { engine.startChicagoFlyby() }
                    Button("Art Institute → Field Museum") { engine.startMuseumCampusFlyby() }
                    Button("Millennium Park → Lincoln Park Zoo") { engine.startNorthSideFlyby() }
                    Button("Lincoln Park Zoo → Wrigley Field") { engine.startNorthSideFlyby(toWrigley: true) }
                    Button("McCormick Place → Robie House") { engine.startRobieFlyby() }
                    Button("Millennium Park → Cultural Center") { engine.startCulturalCenterFlyby() }
                } label: {
                    Label("Chicago connecting flights", systemImage: "airplane")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }.menuStyle(.borderlessButton).fixedSize().glassPanel(radius: 8)
                    .help("Play a continuous flight through the shared Chicago world")
                    .disabled(!engine.isReady)
            }
            if let focused = engine.focusedObjectName {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus: \(focused)").font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                            .lineLimit(1)
                        Text("Drag to orbit · pinch to zoom · click elsewhere to release")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.65))
                    }
                    Button { engine.clearObjectFocus(); engine.focusViewport() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                    }.buttonStyle(.plain).accessibilityLabel("Clear object focus")
                }.padding(.horizontal, 12).padding(.vertical, 9).glassPanel(radius: 9)
                    .frame(maxWidth: 390, alignment: .leading)
            }
            HStack(spacing: 8) {
                Button { engine.setNavigationMode(engine.navigationMode == 1 ? 0:1) } label: {
                    Label(engine.navigationMode == 1 ? "Fly":"Walk",systemImage:engine.navigationMode == 1 ? "airplane":"figure.walk")
                        .font(.system(size: 10,weight:.medium))
                }.buttonStyle(.plain).help("Toggle Walk / Fly · F").accessibilityLabel("Toggle Walk / Fly")
                if engine.location.world == "chicago" {
                    Button { engine.toggleMapMode() } label: { Label("Map mode",systemImage:"square.3.layers.3d.top.filled").font(.system(size:10,weight:.medium)) }
                        .buttonStyle(.plain).help("Fixed top-down map · B").accessibilityLabel("Enter map mode")
                }
                if engine.navigationMode == 1 {
                    Button { engine.stepFlySpeed(-1) } label: { Image(systemName:"minus.circle") }.buttonStyle(.plain).help("Slower flight · −").accessibilityLabel("Slower flight")
                    flySpeedPicker.frame(width:110)
                    Button { engine.stepFlySpeed(1) } label: { Image(systemName:"plus.circle") }.buttonStyle(.plain).help("Faster flight · +").accessibilityLabel("Faster flight")
                    Text("Shift ×3").font(.system(size:9)).foregroundStyle(.white.opacity(0.5))
                }
            }.padding(.horizontal,12).padding(.vertical,8).glassPanel(radius:8).foregroundStyle(accent)
                .disabled(!engine.isReady)
        }.shadow(color: .black.opacity(0.15), radius: 14, y: 3)
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            RendererSelectionMenu(engine: engine, selection: engine.rendererMode, isReady: engine.isReady)
                .equatable()
            Rectangle().fill(.white.opacity(0.13)).frame(width: 1, height: 18)
            AmbientMusicControls(music: engine.music, restoreFocus: engine.focusViewport)
            iconButton("moon.stars", help: "Toggle day / night · N", active: engine.lighting == 2) { engine.toggleDayNight() }
            iconButton(engine.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", help: "Enter / exit full screen · G or ⌃⌘F", active: engine.isFullscreen) { engine.toggleFullscreen() }
            iconButton("slider.horizontal.3", help: "Render settings", active: settingsOpen) { settingsOpen.toggle() }
                .popover(isPresented: $settingsOpen, arrowEdge: .bottom) { settingsPanel }
            iconButton("chart.bar.xaxis", help: "Show performance", active: engine.statsVisible) { engine.statsVisible.toggle() }
            iconButton("camera", help: "Save a render · ⌘⇧S") { engine.captureScreenshot() }
                .disabled(!engine.isReady)
            iconButton("questionmark", help: "Navigation controls · ?", active: engine.showHelp) { engine.showHelp.toggle() }
        }.padding(5).glassPanel(radius: 13)
    }

    private var performancePanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(engine.deviceName.isEmpty ? "INITIALIZING METAL" : engine.deviceName.uppercased())
                .font(.system(size: 9, weight: .medium)).tracking(1.0).foregroundStyle(accent)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.0f", engine.fps)).font(.system(size: 31, weight: .light, design: .rounded)).monospacedDigit()
                Text("FPS").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f ms", engine.gpuMilliseconds)).font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text("GPU FRAME").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(.white.opacity(0.45))
                }
            }
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            metric("Triangles", value: engine.triangleCount.formatted())
            metric(engine.rendererMode == .pathTracing ? "Accumulated samples":"Rendering", value: engine.rendererMode == .pathTracing ? engine.samples.formatted():engine.rendererMode.title)
            metric("Metal allocations", value: engine.memoryMB >= 1024 ? String(format: "%.2f GB", engine.memoryMB / 1024) : String(format: "%.0f MiB", engine.memoryMB))
        }.padding(17).frame(width: 234).glassPanel(radius: 13)
    }

    private var compactPerformancePanel: some View {
        HStack(spacing: 13) {
            Text(String(format: "%.0f FPS", engine.fps)).monospacedDigit().foregroundStyle(accent)
            Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 14)
            Text(String(format: "%.2fM triangles", Double(engine.triangleCount) / 1_000_000)).monospacedDigit()
            Text(String(format: "%.2f GB", engine.memoryMB / 1024)).monospacedDigit().foregroundStyle(.white.opacity(0.55))
        }.font(.system(size: 9, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 10).glassPanel(radius: 10)
    }

    private func metric(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.white.opacity(0.9))
        }.font(.system(size: 10))
    }

    private func tourPanel(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 19) {
            if !compact {
            HStack(alignment: .bottom, spacing: 25) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 9) {
                        Text(engine.chicagoDemoActive ? "CHICAGO DEMO" : (engine.playbackState == .idle ? (engine.idleCycling ? "SLOW VIEW CYCLE" : "SLOW VIEW STUDY") : (engine.playbackState == .manual ? "EXPLORE THE STRUCTURE" : "GUIDED WALKTHROUGH")))
                            .font(.system(size: 9, weight: .semibold)).tracking(2.0).foregroundStyle(accent)
                        Text(String(format: "%02d / %02d", engine.currentStop + 1, engine.stops.count))
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.44))
                    }
                    Text(stop.title).font(.system(size: 24, weight: .regular, design: .serif))
                    Text(stop.detail).font(.system(size: 11)).lineSpacing(3).foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 595, alignment: .leading)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(accent)
                        Text(String(format: "%.1f", engine.altitude)).font(.system(size: 19, weight: .light, design: .rounded)).monospacedDigit()
                        Text("m").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                    Text("CAMERA ELEVATION").font(.system(size: 8, weight: .medium)).tracking(1.3).foregroundStyle(.white.opacity(0.4))
                }
            }.padding(.horizontal, 4)
            }
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Button { engine.toggleTour() } label: {
                        Image(systemName: engine.tourPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.13, green: 0.15, blue: 0.15))
                            .frame(width: 46, height: 46).background(accent, in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).help(engine.tourPlaying ? "Pause walkthrough · Space" : "Play guided walkthrough · Space")
                    Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 32).padding(.horizontal, 5)
                    ScrollViewReader { reader in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(Array(engine.stops.enumerated()), id: \.offset) { index, item in
                                    Button { engine.selectStop(index) } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 6) {
                                                Text(String(format: "%02d", index + 1)).font(.system(size: 9, weight: .medium, design: .monospaced))
                                                if engine.currentStop == index {
                                                                Capsule().fill(accent).frame(width: 15, height: 2)
                                                }
                                                Spacer(minLength: 0)
                                            }.foregroundStyle(engine.currentStop == index ? accent : .white.opacity(0.37))
                                            Text(item.title).font(.system(size: 10, weight: .medium)).lineLimit(2)
                                                .foregroundStyle(engine.currentStop == index ? .white : .white.opacity(0.52))
                                        }
                                        .frame(width: 90, height: 44, alignment: .leading)
                                        .padding(.horizontal, 12).padding(.vertical, 10)
                                        .background(engine.currentStop == index ? .white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 9))
                                        .contentShape(Rectangle())
                                    }.buttonStyle(.plain).help("\(item.subtitle) · Key \(index + 1)").id(index)
                                }
                            }
                        }
                        .onChange(of: engine.currentStop) { _, value in
                            withAnimation(.easeInOut(duration: 0.25)) { reader.scrollTo(value, anchor: .center) }
                        }
                        .onChange(of: engine.location) { _, _ in reader.scrollTo(engine.currentStop, anchor: .center) }
                    }

                }.frame(height: 66).padding(11)
                Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                HStack(spacing: 12) {
                    iconButton("backward.fill", help: "Rewind · ← · press again for 2×, 4×, 8×") { engine.shuttle(.reverse) }
                    iconButton("forward.fill", help: "Fast forward · → · press again for 2×, 4×, 8×") { engine.shuttle(.forward) }
                    Text(engine.transportLabel).font(.system(size: 10, weight: .medium)).foregroundStyle(accent)
                        .frame(width: 135, alignment: .leading)
                    Slider(value: Binding(get: { engine.tourProgress }, set: { engine.seekTour($0) }), in: 0...1,
                           onEditingChanged: { editing in if !editing { engine.focusViewport() } })
                        .tint(accent).accessibilityLabel("Walkthrough timeline")
                    Text(engine.timeLabel).font(.system(size: 10, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(.white.opacity(0.65)).frame(width: 91)
                    Text("PACE").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(.white.opacity(0.45))
                    Picker("Walkthrough speed", selection: Binding(get: { engine.playbackSpeed }, set: { engine.setPlaybackSpeed($0) })) {
                        ForEach(WalkthroughPlayback.speeds, id: \.self) { speed in Text(String(format: "%g×", speed)).tag(speed) }
                    }.labelsHidden().frame(width: 74).help("Walkthrough pace; shuttle speeds multiply this pace")
                }.padding(.horizontal, 12).padding(.vertical, 7)
                Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                HStack(spacing: 12) {
                    Button { engine.toggleIdleCycling() } label: {
                        Label(engine.idleCycling ? "Idle Pause" : "Idle Play", systemImage: engine.idleCycling ? "pause.circle" : "play.circle")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(engine.idleCycling ? accent : .white.opacity(0.8))
                            .frame(width: 92, alignment: .leading)
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .background(engine.idleCycling ? .white.opacity(0.09) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).help("Start or pause automatic view cycling · I. Pausing keeps this view's gentle motion.")
                    Text("IDLE SPEED").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(.white.opacity(0.45))
                    Picker("Idle speed", selection: Binding(get: { engine.idleSpeed }, set: { engine.setIdleSpeed($0) })) {
                        ForEach(WalkthroughPlayback.speeds, id: \.self) { speed in Text(String(format: "%g×", speed)).tag(speed) }
                    }.labelsHidden().frame(width: 74).help("Gentle motion and view cycling speed · [ slower / ] faster")
                    Text(idleStatus)
                        .font(.system(size: 10)).monospacedDigit().foregroundStyle(.white.opacity(0.53))
                    Spacer(minLength: 0)
                    Text(engine.chicagoDemoActive
                         ? String(format: "≈%.0fm per Chicago pass at %g×", WalkthroughPlayback.chicagoDemoDuration / engine.playbackSpeed / 60, engine.playbackSpeed)
                         : String(format: "%.0fs per view at %g×", WalkthroughPlayback.idleViewDuration / engine.idleSpeed, engine.idleSpeed))
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }.padding(.horizontal, 12).padding(.vertical, 7)
            }.glassPanel(radius: 14)
            HStack(spacing: 13) {
                Link("Map data © OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    .foregroundStyle(.white.opacity(0.46)).help("OpenStreetMap attribution and license")
                Circle().fill(.white.opacity(0.25)).frame(width: 2, height: 2)
                Text("Space play   C demo   ↑ / ↓ views   M inset map   B map mode   T look down   R ray toggle   G full screen   N day/night").lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Button("H  hide interface") { presentation.chromeVisible = false }.buttonStyle(.plain)
            }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.46)).padding(.horizontal, 4)
        }
    }

    private var idleStatus: String {
        if engine.chicagoDemoActive { return "Full walkthroughs · day/night alternates after Chicago" }
        guard engine.idleCycling else { return "Holding this view · Idle Play resumes" }
        let description = engine.location == .skyline ? "Daylight, sunset & night" : (engine.lighting == 2 ? "Night pass" : "Day pass")
        return String(format:"%@ · next view in %.0fs",description,ceil(engine.idleSecondsRemaining))
    }
    private var flySpeedPicker: some View {
        Picker("Flight speed",selection:Binding(get:{engine.flySpeed},set:{engine.setFlySpeed($0);engine.focusViewport()})) {
            ForEach(ManualCityNavigation.flySpeeds,id: \.self) { speed in
                Text(String(format:"%.0f m/s",speed)).tag(speed)
            }
        }.pickerStyle(.menu).labelsHidden().help("Flight speed · default 400 m/s · Shift triples speed · − / + step presets")
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 21) {
            Text("Render settings").font(.system(size: 21, weight: .regular, design: .serif))
            Picker("Renderer",selection:Binding(get:{engine.rendererMode},set:{engine.setRendererMode($0)})) {
                ForEach(ArchitectureRendererMode.allCases) { mode in Text(mode.title).tag(mode) }
            }.pickerStyle(.menu)
            Text(engine.rendererMode.explanation + " R switches Fast Raster and the last selected ray tracer.")
                .font(.system(size:10)).foregroundStyle(.secondary).lineSpacing(3)
            VStack(alignment: .leading, spacing: 9) {
                settingLabel("QUALITY", value: ["Responsive exploration", "Balanced detail", "Maximum refinement"][min(max(engine.quality, 0), 2)])
                Picker("Quality", selection: Binding(get: { engine.quality }, set: { engine.setQuality($0) })) {
                    Text("Interactive").tag(0); Text("Balanced").tag(1); Text("Ultra").tag(2)
                }.pickerStyle(.segmented).labelsHidden()
                Text(engine.rendererMode == .pathTracing ? "Hold the camera still to progressively refine reflections, shadows, and indirect light.":"Quality changes the viewport resolution. \(engine.rendererMode.title) draws each view without progressive indirect-light refinement.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
            }
            VStack(alignment: .leading, spacing: 9) {
                settingLabel("LIGHTING", value: "")
                Picker("Lighting", selection: Binding(get: { engine.lighting }, set: { engine.setLighting($0) })) {
                    Text("Golden").tag(0); Text("Daylight").tag(1); Text("Sunset").tag(3); Text("Night").tag(2)
                }.pickerStyle(.segmented).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 9) {
                settingLabel("EXPOSURE", value: String(format: "%.2f×", engine.exposure))
                Slider(value: Binding(get: { engine.exposure }, set: { engine.setExposure($0) }), in: 0.35...2.5)
                    .tint(accent).accessibilityLabel("Exposure")
            }
            VStack(alignment: .leading, spacing: 9) {
                settingLabel("NAVIGATION", value: "")
                Picker("Navigation", selection: Binding(get:{engine.navigationMode},set:{engine.setNavigationMode($0)})) {
                    Text("Walk").tag(0); Text("Fly").tag(1)
                    if engine.location.world == "chicago" { Text("Map").tag(2) }
                }.pickerStyle(.segmented).labelsHidden()
                Text("Map stays north-up: WASD or drag pans, Shift triples key speed, and pinch or scroll zooms. Walk follows solid floors; Fly moves freely.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
                settingLabel("FLY SPEED",value:String(format:"%.0f m/s · Shift ×3",engine.flySpeed))
                flySpeedPicker.disabled(engine.isMapMode)
            }
            Button { engine.resetView(); settingsOpen = false } label: {
                Label("Return to the opening view", systemImage: "arrow.counterclockwise").font(.system(size: 11))
            }.buttonStyle(.plain).foregroundStyle(accent).disabled(engine.isMapMode)
        }.padding(24).frame(width: 348).preferredColorScheme(.dark)
    }

    private func settingLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(accent)
            Spacer()
            Text(value).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var loadingPanel: some View {
        VStack(spacing: 17) {
            if let error = engine.errorMessage {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 26)).foregroundStyle(accent)
                Text("The scene could not open").font(.system(size: 22, design: .serif))
                Text(error).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                ProgressView().controlSize(.small)
                Text("Assembling an icon").font(.system(size: 24, weight: .regular, design: .serif))
                Text(engine.status).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }.padding(32).frame(width: 380).glassPanel(radius: 18)
    }

    private var helpPanel: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { engine.showHelp = false }
            ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("MAKE YOUR OWN WAY").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(accent)
                        Text("A closer perspective").font(.system(size: 29, weight: .regular, design: .serif))
                    }
                    Spacer()
                    iconButton("xmark", help: "Close controls") { engine.showHelp = false }
                }
                Text("Idle Play cycles through every view in order, alternating a daytime pass and a nighttime pass. Selecting a view holds its gentle motion. Space starts or pauses that view’s walkthrough; the timeline shows its full duration. Idle speed changes both gentle motion and time per view. Press N to switch day and night without restarting your route.")
                    .font(.system(size: 12)).lineSpacing(4).foregroundStyle(.white.opacity(0.62))
                Text("Chicago Demo starts at a random Chicago location and view, then plays all \(WalkthroughPlayback.chicagoDemoRouteCount) routes sequentially. Select any Chicago location or view to continue the demo there. ↑ and ↓ move to the previous or next route across location boundaries. Space pauses and resumes; city wraps alternate day/night. Selecting Paris, Idle Play or manual camera control leaves the demo. Click a landmark to focus it, drag to orbit and scroll to zoom; click elsewhere or press Escape to release focus. Window dragging holds the camera and animation in place.")
                    .font(.system(size: 12)).lineSpacing(4).foregroundStyle(.white.opacity(0.62))
                VStack(spacing: 10) {
                    helpRow("W  A  S  D", "Move forward, left, back, right parallel to the ground")
                    helpRow("MAP + WASD", "Pan north, west, south, east · Shift triples speed")
                    helpRow("Q  /  E", "Ascend / descend in Fly mode")
                    helpRow("SHIFT", "Triple manual movement speed")
                    helpRow("F  /  −  /  +", "Walk/Fly · slower/faster flight (8–800 m/s)")
                    helpRow("CLICK", "Focus a landmark; click elsewhere to release")
                    helpRow("LEFT DRAG", "Pan across the city; orbit if a landmark is focused")
                    helpRow("SHIFT + DRAG", "Hold Shift and left-drag to rotate the view")
                    helpRow("RIGHT DRAG", "Look around, or orbit a focused landmark")
                    helpRow("SCROLL", "Zoom toward focus; otherwise step flight presets")
                    helpRow("M", "Show/hide inset map; labels and dots center and focus landmarks")
                    helpRow("B", "Enter or leave fixed north-up Map mode")
                    helpRow("T", "Point the normal camera straight down; keep normal controls")
                    helpRow("PINCH", "Zoom the normal view, focused object, or city map")
                    helpRow("R", "Toggle last ray tracer / Fast Raster at the same camera")
                    helpRow("G / ⌃⌘F", "Enter or exit full screen, including in Map mode")
                    helpRow("MUSIC NOTE", "Ambient music on/off, volume and current song")
                    helpRow("C", "Start / stop the complete Chicago demo")
                    helpRow("SPACE", "Start / pause / resume this walkthrough")
                    helpRow("←  /  →", "Rewind / fast forward; repeat for 2× / 4× / 8×")
                    helpRow("↑  /  ↓", "Previous / next view; cross locations during Chicago Demo")
                    helpRow("I", "Idle Play / Pause: cycle views / hold this view")
                    helpRow("[  /  ]", "Slower / faster idle motion and view cycling")
                    helpRow("PACE / TIMELINE", "Set 0.25×–4× speed / seek to a time")
                    helpRow("1 – \(engine.stops.count)", "Select a view; continue there during Chicago Demo")
                    helpRow("L", "Cycle destinations; stay within Chicago during its demo")
                    helpRow("N", "Toggle day / night; preserve camera and playback")
                    helpRow("⌃ ⌘ F", "Enter / exit full screen; resize from any edge")
                    helpRow("H", "Show / hide the interface")
                    helpRow("ESC", "Release navigation / close this panel")
                    helpRow("⌘ ⇧ S", "Save the current render")
                }
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                Text("The structure is a procedural architectural interpretation. Explore the façades, platforms, and observation spaces at your own pace.")
                    .font(.system(size: 10)).lineSpacing(3).foregroundStyle(.white.opacity(0.42))
            }.padding(30).frame(width: 530)
            }.frame(width: 530, height: 600).glassPanel(radius: 20)
        }
    }

    private func helpRow(_ keys: String, _ description: String) -> some View {
        HStack(spacing: 20) {
            Text(keys).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(accent).frame(width: 133, alignment: .leading)
            Text(description).font(.system(size: 11)).foregroundStyle(.white.opacity(0.74))
            Spacer(minLength: 0)
        }
    }

    private func iconButton(_ symbol: String, help: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? accent : .white.opacity(0.72))
                .frame(width: 33, height: 32)
                .background(active ? .white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(help)
    }
}

@MainActor
private struct AmbientMusicControls: View {
    @ObservedObject var music: AmbientMusicController
    let restoreFocus: () -> Void
    @State private var isOpen = false
    private let accent = Color(red:0.84,green:0.75,blue:0.55)
    var body: some View {
        Button { isOpen.toggle() } label: {
            Image(systemName: music.isEnabled ? "music.note" : "speaker.slash")
                .font(.system(size:12,weight:.medium)).foregroundStyle(music.isEnabled ? accent : .white.opacity(0.6))
                .frame(width:33,height:32).contentShape(Rectangle())
        }.buttonStyle(.plain).help("Ambient music · on/off and volume").accessibilityLabel("Ambient music settings")
        .popover(isPresented:$isOpen,arrowEdge:.bottom) {
            VStack(alignment:.leading,spacing:18) {
                Text("Music for the city").font(.system(size:22,design:.serif))
                Toggle("Ambient music",isOn:Binding(get:{music.isEnabled},set:{music.setEnabled($0)}))
                VStack(alignment:.leading,spacing:6) {
                    Text(music.errorMessage != nil ? "MUSIC UNAVAILABLE" : (music.isEnabled ? "NOW PLAYING" : "MUSIC PAUSED")).font(.system(size:9,weight:.semibold)).tracking(1.5).foregroundStyle(accent)
                    Text(music.currentTitle).font(.system(size:12))
                }
                if let error = music.errorMessage { Text(error).font(.system(size:10)).foregroundStyle(.secondary) }
                HStack { Text("Volume"); Spacer(); Text(String(format:"%.0f%%",music.volume*100)).monospacedDigit() }.font(.system(size:11))
                Slider(value:Binding(get:{music.volume},set:{music.setVolume($0)}),in:0...1).tint(accent).accessibilityLabel("Music volume")
                Text("An original ambient piece for each destination. Songs blend into the next; changing locations starts its assigned piece.")
                    .font(.system(size:10)).foregroundStyle(.secondary).lineSpacing(3)
            }.padding(24).frame(width:300).preferredColorScheme(.dark)
        }
        .onChange(of:isOpen) { _,value in if !value { restoreFocus() } }
    }
}

private extension View {
    func glassPanel(radius: CGFloat) -> some View {
        self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(Color(red: 0.045, green: 0.065, blue: 0.074).opacity(0.47), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.12), lineWidth: 0.7))
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

@MainActor
private struct MetalArchitectureViewport: NSViewRepresentable {
    let engine: EngineController
    let presentation: PresentationState
    func makeNSView(context: Context) -> ArchitectureMetalView {
        let view = ArchitectureMetalView(frame: .zero)
        view.engine = engine
        view.presentation = presentation
        engine.attach(view: view)
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    func updateNSView(_ nsView: ArchitectureMetalView, context: Context) {}
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ArchitectureMetalView, context: Context) -> CGSize? {
        // A Metal drawable has pixels, not a useful intrinsic SwiftUI size.
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}

@MainActor
private final class ArchitectureMetalView: MTKView, ViewportInputResetting {
    weak var engine: EngineController?
    weak var presentation: PresentationState?
    private var heldKeys = Set<UInt16>()
    private var pointerGesture = ViewportPointerGesture()
    private var magnifying = false
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    private func pointerPoint(_ event: NSEvent) -> SIMD2<Float> {
        let local = convert(event.locationInWindow, from: nil)
        return SIMD2(Float(local.x - bounds.minX), Float(bounds.maxY - local.y))
    }
    private var windowOrigin: SIMD2<Double> {
        SIMD2(Double(window?.frame.minX ?? 0), Double(window?.frame.minY ?? 0))
    }
    private func isViewportEvent(_ event: NSEvent) -> Bool {
        guard let window, engine?.isReady == true, engine?.showHelp == false, !inLiveResize else { return false }
        // The full-size Metal view extends beneath the transparent native titlebar.
        // Its pixels do not make the titlebar a camera interaction surface.
        return window.contentLayoutRect.contains(event.locationInWindow)
            && bounds.contains(convert(event.locationInWindow, from: nil))
    }
    private func beginPointer(_ event: NSEvent, button: ViewportPointerGesture.Button) {
        let inside = isViewportEvent(event)
        pointerGesture.begin(button: button, point: pointerPoint(event), windowOrigin: windowOrigin, insideViewport: inside)
        if inside { window?.makeFirstResponder(self) }
    }
    private func dragPointer(_ event: NSEvent, button: ViewportPointerGesture.Button) {
        guard engine?.showHelp == false else { pointerGesture.cancel(); return }
        if let delta = pointerGesture.drag(button: button, point: pointerPoint(event), windowOrigin: windowOrigin) {
            // View-local displacement never counts native window translation as a
            // camera delta; ownership is also cancelled if the window origin moves.
            switch ViewportPointerGesture.action(button:button,shift:event.modifierFlags.contains(.shift),mapMode:engine?.isMapMode == true) {
            case .pan:
                let point = pointerPoint(event)
                engine?.pan(from:point-delta,to:point,viewport:SIMD2(Float(bounds.width),Float(bounds.height)))
            case .look: engine?.look(deltaX: delta.x, deltaY: delta.y)
            case .ignore: break
            }
        }
    }
    override func mouseDown(with event: NSEvent) {
        if let window, !window.styleMask.contains(.fullScreen),
           event.locationInWindow.y >= window.contentLayoutRect.maxY {
            releaseKeys(); engine?.windowWillMove()
            window.performDrag(with: event)
            return
        }
        beginPointer(event, button: .left)
    }
    override func mouseDragged(with event: NSEvent) { dragPointer(event, button: .left) }
    override func mouseUp(with event: NSEvent) {
        guard let point = pointerGesture.end(button: .left, point: pointerPoint(event), windowOrigin: windowOrigin),
              isViewportEvent(event), bounds.width > 0, bounds.height > 0 else { return }
        engine?.focusObject(at: SIMD2(point.x / Float(bounds.width), point.y / Float(bounds.height)), aspect: Float(bounds.width / bounds.height))
    }
    override func rightMouseDown(with event: NSEvent) { beginPointer(event, button: .right) }
    override func rightMouseDragged(with event: NSEvent) { dragPointer(event, button: .right) }
    override func rightMouseUp(with event: NSEvent) {
        _ = pointerGesture.end(button: .right, point: pointerPoint(event), windowOrigin: windowOrigin)
    }
    override func magnify(with event: NSEvent) {
        // A gesture can finish outside the content rectangle. Always release
        // its scroll suppression even when the final event cannot change zoom.
        defer {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                magnifying = false; pointerGesture.cancel()
            }
        }
        guard isViewportEvent(event) else { return }
        if event.phase.contains(.began) { releaseKeys(); magnifying = true; pointerGesture.cancel() }
        engine?.magnify(event.magnification)
    }
    override func rotate(with event: NSEvent) { /* Orientation belongs to explicit viewport drags. */ }
    override func scrollWheel(with event: NSEvent) {
        guard isViewportEvent(event), !magnifying else { return }
        engine?.scroll(Float(event.scrollingDeltaY), precise: event.hasPreciseScrollingDeltas)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        guard let engine, ViewportPointerGesture.allowsKey(event.keyCode,mapMode:engine.isMapMode) else { return }
        if !event.isARepeat {
            switch event.keyCode {
            case 5: engine.toggleFullscreen(); return
            case 17: engine.pointCameraDown(); return
            case 11: engine.toggleMapMode(); return
            case 49: engine.toggleTour(); return
            case 123: engine.shuttle(.reverse); return
            case 124: engine.shuttle(.forward); return
            case 126: engine.cycleView(-1); return
            case 125: engine.cycleView(1); return
            case 34: engine.toggleIdleCycling(); return
            case 8: engine.toggleChicagoDemo(); return
            case 37: engine.toggleLocation(); return
            case 45: engine.toggleDayNight(); return
            case 46: engine.toggleNavigationMap(); return
            case 15: engine.toggleRayTracing(); return
            case 3: engine.setNavigationMode(engine.navigationMode == 1 ? 0:1); return
            case 27, 78: if engine.isMapMode { engine.zoomMap(false) } else { engine.stepFlySpeed(-1) }; return
            case 24, 69: if engine.isMapMode { engine.zoomMap(true) } else { engine.stepFlySpeed(1) }; return
            case 33: engine.stepIdleSpeed(-1); return
            case 30: engine.stepIdleSpeed(1); return
            case 4: presentation?.chromeVisible.toggle(); return
            case 44: engine.showHelp.toggle(); return
            case 53:
                releaseKeys()
                engine.showHelp = false
                if engine.isMapMode { engine.toggleMapMode() } else { engine.clearObjectFocus() }
                engine.focusViewport()
                return
            default: break
            }
            let stopKeys: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
            if let index = stopKeys.firstIndex(of: event.keyCode), index < engine.stops.count {
                engine.selectStop(index)
                return
            }
        }
        let movement: Set<UInt16> = [13, 0, 1, 2, 12, 14]
        if movement.contains(event.keyCode), !engine.showHelp, !event.isARepeat {
            // Continuous motion comes from the held set, not repeat events.
            // After a lifecycle reset, require a fresh press before moving.
            let shifted = event.modifierFlags.contains(.shift)
            engine.moveKey(56, pressed: shifted)
            if shifted { heldKeys.insert(56) } else { heldKeys.remove(56) }
            heldKeys.insert(event.keyCode)
            engine.moveKey(event.keyCode, pressed: true)
        }
    }

    override func keyUp(with event: NSEvent) {
        heldKeys.remove(event.keyCode)
        engine?.moveKey(event.keyCode, pressed: false)
    }

    override func flagsChanged(with event: NSEvent) {
        engine?.moveKey(56, pressed: event.modifierFlags.contains(.shift))
        if event.modifierFlags.contains(.shift) { heldKeys.insert(56) } else { heldKeys.remove(56) }
    }

    override func resignFirstResponder() -> Bool { releaseKeys(); return super.resignFirstResponder() }
    override func viewDidMoveToWindow() {
        releaseKeys()
        super.viewDidMoveToWindow()
        for name in [NSWindow.didResignKeyNotification, NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification, NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification, NSWindow.willMoveNotification] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowLostFocus), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillMove), name: NSWindow.willMoveNotification, object: window)
            for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(windowPresentationChanged), name: name, object: window)
            }
            for name in [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(windowTransitionStarted), name: name, object: window)
            }
            engine?.windowPresentationChanged()
        }
    }
    @objc private func windowPresentationChanged() { releaseKeys(); engine?.windowPresentationChanged() }
    @objc private func windowTransitionStarted() { releaseKeys() }
    @objc private func windowWillMove() { releaseKeys(); engine?.windowWillMove() }
    @objc private func windowLostFocus() { releaseKeys() }
    func cancelViewportInput() { releaseKeys() }
    override func viewWillStartLiveResize() { releaseKeys(); super.viewWillStartLiveResize() }
    override func viewDidEndLiveResize() { super.viewDidEndLiveResize(); engine?.drawableSizeDidChange(drawableSize) }
    private func releaseKeys() {
        magnifying = false
        pointerGesture.cancel()
        for key in heldKeys { engine?.moveKey(key, pressed: false) }
        heldKeys.removeAll()
    }
}
