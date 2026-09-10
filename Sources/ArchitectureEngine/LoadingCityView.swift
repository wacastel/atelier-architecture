import SwiftUI

/// Loading chrome remains transparent around its two cards so the first city
/// frame is visible immediately, including the brief completed-state hold.
struct LoadingCityView: View {
    let snapshot: CityLoadingSnapshot
    let isChicago: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var facts = ChicagoFactRotation()

    private let gold=Color(red:0.84,green:0.75,blue:0.51)
    private let ink=Color(red:0.065,green:0.085,blue:0.090)
    private var progress: Double { snapshot.progress.isFinite ? max(0,min(1,snapshot.progress)):0 }
    private var showingFacts: Bool { isChicago && progress < 1 }
    private var currentFact: ChicagoFact? {
        facts.currentIndex.flatMap { ChicagoFacts.all.indices.contains($0) ? ChicagoFacts.all[$0]:nil }
    }

    var body: some View {
        GeometryReader { geometry in
            let compact=geometry.size.height < 780
            VStack(spacing:compact ? 18:28) {
                Spacer(minLength:12)
                loadingCard(compact:compact)
                    .frame(maxWidth:640)
                Spacer(minLength:18)
                if showingFacts,let fact=currentFact {
                    factCard(fact,compact:compact)
                        .frame(maxWidth:790)
                }
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity)
            .padding(.horizontal,geometry.size.width < 1000 ? 28:48)
            .padding(.top,compact ? 24:56)
            .padding(.bottom,compact ? 32:48)
        }
        .allowsHitTesting(false)
        .task(id:showingFacts) {
            guard showingFacts else { return }
            _=facts.tick(at:ProcessInfo.processInfo.systemUptime)
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds:3_000_000_000) }
                catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil:.easeInOut(duration:0.45)) {
                    _=facts.tick(at:ProcessInfo.processInfo.systemUptime)
                }
            }
        }
    }

    private func loadingCard(compact: Bool) -> some View {
        VStack(alignment:.leading,spacing:compact ? 15:19) {
            HStack(alignment:.top,spacing:16) {
                Image(systemName:progress >= 1 ? "checkmark.seal":"building.2.crop.circle")
                    .font(.system(size:compact ? 32:38,weight:.ultraLight))
                    .foregroundStyle(gold)
                    .frame(width:44,height:44)
                    .accessibilityHidden(true)
                VStack(alignment:.leading,spacing:6) {
                    Text(isChicago ? "ATELIER / CHICAGO":"ATELIER / PARIS")
                        .font(.system(size:10,weight:.semibold,design:.rounded))
                        .tracking(2.7).foregroundStyle(gold)
                    Text(progress >= 1 ? "Your city is ready":snapshot.title)
                        .font(.system(size:compact ? 26:30,weight:.regular,design:.serif))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength:4)
                VStack(alignment:.trailing,spacing:5) {
                    Text("\(Int((progress*100).rounded()))%")
                        .font(.system(size:compact ? 29:34,weight:.light,design:.rounded))
                        .monospacedDigit().foregroundStyle(gold)
                    Text(elapsedText(snapshot.elapsed))
                        .font(.system(size:10,weight:.medium,design:.monospaced))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
            VStack(alignment:.leading,spacing:9) {
                GeometryReader { bar in
                    ZStack(alignment:.leading) {
                        Capsule().fill(.white.opacity(0.075))
                        Capsule().fill(LinearGradient(colors:[gold.opacity(0.6),gold],startPoint:.leading,endPoint:.trailing))
                            .frame(width:bar.size.width*progress)
                    }
                }
                .frame(height:4)
                .animation(reduceMotion ? nil:.easeOut(duration:0.2),value:progress)
                .accessibilityLabel("City loading progress")
                .accessibilityValue("\(Int((progress*100).rounded())) percent")
                Text(progress >= 1 ? "The viewport is ready to explore.":snapshot.currentStep)
                    .font(.system(size:12,weight:.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            Rectangle().fill(.white.opacity(0.08)).frame(height:1)
            LazyVGrid(columns:[GridItem(.flexible(),spacing:24),GridItem(.flexible())],alignment:.leading,spacing:compact ? 10:13) {
                ForEach(snapshot.steps) { step in stepRow(step) }
            }
        }
        .padding(compact ? 23:28)
        .background(ink.opacity(0.97),in:RoundedRectangle(cornerRadius:22))
        .overlay(RoundedRectangle(cornerRadius:22).strokeBorder(.white.opacity(0.09),lineWidth:1))
        .shadow(color:.black.opacity(0.22),radius:28,y:12)
        .accessibilityElement(children:.contain)
    }

    private func stepRow(_ step: CityLoadingStep) -> some View {
        HStack(spacing:9) {
            Image(systemName:step.state == .completed ? "checkmark.circle.fill":step.state == .active ? "circle.inset.filled":"circle")
                .font(.system(size:12,weight:.regular))
                .foregroundStyle(step.state == .pending ? .white.opacity(0.18):gold)
                .frame(width:14)
                .accessibilityHidden(true)
            Text(step.title)
                .font(.system(size:11,weight:step.state == .active ? .semibold:.regular))
                .foregroundStyle(step.state == .pending ? .white.opacity(0.32):.white.opacity(0.82))
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength:2)
            if let duration=step.duration,duration.isFinite,step.state == .completed {
                Text(String(format:"%.1fs",max(0,duration)))
                    .font(.system(size:10,weight:.regular,design:.monospaced))
                    .foregroundStyle(gold.opacity(0.67))
            }
        }
        .frame(minHeight:20)
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("\(step.title), \(step.state == .completed ? "complete":step.state == .active ? "in progress":"waiting")")
    }

    private func factCard(_ fact: ChicagoFact,compact: Bool) -> some View {
        HStack(alignment:.top,spacing:15) {
            Image(systemName:"sparkle")
                .font(.system(size:19,weight:.light))
                .foregroundStyle(gold.opacity(0.85))
                .padding(.top,4)
                .accessibilityHidden(true)
            VStack(alignment:.leading,spacing:5) {
                HStack {
                    Text("CHICAGO, IN A FEW WORDS")
                        .font(.system(size:9,weight:.semibold)).tracking(2.2)
                        .foregroundStyle(gold)
                    Spacer()
                    Text(fact.source.title)
                        .font(.system(size:9,weight:.regular))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
                Text(fact.text)
                    .font(.system(size:compact ? 14:16,weight:.regular,design:.serif))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .frame(maxWidth:.infinity,alignment:.leading)
                    .id(fact.id)
                    .transition(reduceMotion ? .identity:.asymmetric(insertion:.opacity.combined(with:.move(edge:.bottom)),removal:.opacity))
            }
        }
        .padding(.horizontal,22).padding(.vertical,17)
        .frame(height:compact ? 88:94,alignment:.center)
        .background(ink.opacity(0.95),in:RoundedRectangle(cornerRadius:15))
        .overlay(RoundedRectangle(cornerRadius:15).strokeBorder(gold.opacity(0.12),lineWidth:1))
        .clipped()
        // Timer changes remain readable on demand without interrupting the
        // user's VoiceOver speech every three seconds.
        .accessibilityElement(children:.ignore)
        .accessibilityLabel("Chicago fact. \(fact.text) Source: \(fact.source.title)")
    }

    private func elapsedText(_ seconds: Double) -> String {
        let safe=seconds.isFinite ? max(0,seconds):0
        return safe<60 ? String(format:"%.1f SEC",safe):String(format:"%d:%02d ELAPSED",Int(safe)/60,Int(safe)%60)
    }
}
