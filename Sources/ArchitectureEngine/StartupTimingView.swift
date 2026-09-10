import SwiftUI
import AppKit

struct StartupTimingView: View {
    let snapshot: CityLoadingSnapshot
    let rayPreparing: Bool
    let rayReadySeconds: Double?
    let rayError: String?
    private let gold=Color(red:0.84,green:0.75,blue:0.51)
    var body: some View {
        VStack(alignment:.leading,spacing:15) {
            Text("STARTUP MEASUREMENTS").font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(gold)
            HStack(alignment:.firstTextBaseline) {
                Text(snapshot.progress>=1 ? "City displayed":"Preparing the city").font(.system(size:22,design:.serif))
                Spacer()
                Text(String(format:"%.2f s",snapshot.elapsed)).font(.system(size:21,weight:.light,design:.rounded)).monospacedDigit().foregroundStyle(gold)
            }
            ForEach(snapshot.steps) { step in
                HStack {
                    Text(step.title).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(step.duration.map{String(format:"%.3f s",$0)} ?? (step.state == .active ? "In progress":"Waiting"))
                        .monospacedDigit().foregroundStyle(gold.opacity(0.85))
                }.font(.system(size:11))
            }
            Divider()
            HStack {
                Text("Ray-tracing resources").foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(rayError != nil ? "Unavailable · using Fast Raster":(rayReadySeconds.map{String(format:"Ready at %.2f s",$0)} ?? (rayPreparing ? "Preparing in background":"Waiting for first frame")))
                    .monospacedDigit().foregroundStyle(gold)
            }.font(.system(size:11))
            if let rayError {
                Text(rayError).font(.system(size:10)).foregroundStyle(.orange.opacity(0.8)).fixedSize(horizontal:false,vertical:true)
            }
            Text("The city appears in Fast Raster while ray tracing prepares. Your selected renderer takes over automatically. Navigation loads in parallel, so step durations overlap.")
                .font(.system(size:11)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal:false,vertical:true)
            Button("Open detailed launch report") {
                let url=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Atelier/last-startup.json")
                NSWorkspace.shared.open(url)
            }.font(.system(size:11)).disabled(snapshot.progress<1)
        }.padding(24).frame(width:430).preferredColorScheme(.dark)
    }
}
