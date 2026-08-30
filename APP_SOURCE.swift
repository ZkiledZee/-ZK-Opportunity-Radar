import SwiftUI
import Combine
import UserNotifications

enum Theme {
    static let bg = Color(red: 0.01, green: 0.02, blue: 0.025)
    static let card = Color(red: 0.035, green: 0.055, blue: 0.063)
    static let border = Color(red: 0.11, green: 0.20, blue: 0.20)
    static let green = Color(red: 0.13, green: 0.94, blue: 0.62)
    static let cyan = Color(red: 0.22, green: 0.80, blue: 1.00)
    static let amber = Color(red: 1.00, green: 0.72, blue: 0.24)
    static let muted = Color(red: 0.58, green: 0.66, blue: 0.68)
    static let gradient = LinearGradient(colors: [green, cyan], startPoint: .leading, endPoint: .trailing)
}

enum Category: String, CaseIterable, Identifiable {
    case all = "All", roofing = "Roofing", lofts = "Lofts", extensions = "Extensions", newBuilds = "New Builds"
    var id: String { rawValue }
}

struct Opportunity: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let area: String
    let postcode: String
    let miles: Double
    let category: Category
    let score: Int
    let status: String
    let age: String
    let value: String
    let summary: String
    let work: [String]

    static let demo = [
        Opportunity(title: "Two-storey side and rear extension", area: "Bradford", postcode: "BD4", miles: 3.2, category: .roofing, score: 91, status: "Approved", age: "18 min ago", value: "£45k–£75k", summary: "New pitched roof, rooflights and drainage are shown in the demonstration project scope.", work: ["Pitched roof", "Rooflights", "Guttering", "Leadwork"]),
        Opportunity(title: "Hip-to-gable loft conversion", area: "Shipley", postcode: "BD18", miles: 5.7, category: .lofts, score: 86, status: "Submitted", age: "1 hr ago", value: "£35k–£55k", summary: "Hip-to-gable alteration with a rear dormer and three front rooflights.", work: ["Roof alteration", "Dormer covering", "Rooflights", "Insulation"]),
        Opportunity(title: "Detached dwelling with garage", area: "Pudsey", postcode: "LS28", miles: 7.9, category: .newBuilds, score: 82, status: "Approved", age: "Today", value: "£180k–£260k", summary: "New detached dwelling with an integral garage and a complete roofing package.", work: ["Roof structure", "Tiles", "Rainwater system", "Garage roof"]),
        Opportunity(title: "Single-storey kitchen extension", area: "Bingley", postcode: "BD16", miles: 8.4, category: .extensions, score: 77, status: "Approved", age: "Yesterday", value: "£25k–£40k", summary: "Rear kitchen extension with a shallow pitched tiled roof and two roof windows.", work: ["Extension roof", "Roof windows", "Fascia", "Guttering"]),
        Opportunity(title: "Replacement roof and solar panels", area: "Keighley", postcode: "BD21", miles: 11.8, category: .roofing, score: 74, status: "Submitted", age: "Yesterday", value: "£18k–£30k", summary: "Replacement slate covering, integrated solar and chimney repairs.", work: ["Slate roof", "Solar integration", "Chimney repair", "Scaffolding"])
    ]
}

@MainActor
final class RadarStore: ObservableObject {
    @Published var category: Category = .all
    @Published var saved = Set<UUID>()
    @Published var radius = 15.0
    @Published var search = ""
    @Published var scanning = false
    @Published var scanText = "Demo feed ready"
    @Published var alerts = false
    let projects = Opportunity.demo

    var visible: [Opportunity] {
        projects.filter { category == .all || $0.category == category }
            .filter { $0.miles <= radius }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.area.localizedCaseInsensitiveContains(search) || $0.postcode.localizedCaseInsensitiveContains(search) }
            .sorted { $0.score > $1.score }
    }

    func toggle(_ item: Opportunity) {
        if saved.contains(item.id) { saved.remove(item.id) } else { saved.insert(item.id) }
    }

    func scan() async {
        guard !scanning else { return }
        scanning = true
        scanText = "Checking local sources…"
        try? await Task.sleep(for: .seconds(1))
        scanText = "Analysing project fit…"
        try? await Task.sleep(for: .seconds(1))
        scanText = "5 demo opportunities ranked"
        scanning = false
    }

    func enableAlerts() async {
        alerts = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func letter(_ item: Opportunity) -> String {
        """
        Dear Property Owner,

        We noticed the recently published planning proposal concerning \(item.title.lowercased()) in \(item.postcode).

        We are a local roofing contractor serving \(item.area) and the surrounding area. Our team can assist with \(item.work.joined(separator: ", ").lowercased()).

        If you have not yet appointed a roofing contractor, we would be pleased to discuss the project and provide a no-obligation quotation.

        Kind regards,
        [Your company name]
        [Telephone number]
        """
    }
}

@main
struct ZKOpportunityRadarApp: App {
    @StateObject private var store = RadarStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            HomeView(tab: $tab).tag(0).tabItem { Label("Radar", systemImage: "scope") }
            FeedView().tag(1).tabItem { Label("Opportunities", systemImage: "bolt.fill") }
            SavedView().tag(2).tabItem { Label("Saved", systemImage: "bookmark.fill") }
            SettingsView().tag(3).tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }.tint(Theme.green)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: RadarStore
    @Binding var tab: Int
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ZK").font(.system(size: 13, weight: .black, design: .rounded)).tracking(3).foregroundStyle(Theme.green)
                            Text("OPPORTUNITY RADAR").font(.system(size: 20, weight: .black, design: .rounded))
                        }
                        Spacer()
                        Pill(text: store.scanning ? "Scanning" : "Demo", color: store.scanning ? Theme.green : Theme.amber)
                    }
                    RadarAnimation().frame(height: 250)
                    Text(store.scanText).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.muted)
                    Button { Task { await store.scan() } } label: {
                        Label(store.scanning ? "SCANNING" : "SCAN NOW", systemImage: "scope")
                            .font(.system(size: 12, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.gradient).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.disabled(store.scanning)
                    HStack(spacing: 9) {
                        Stat(value: "5", label: "Detected", color: Theme.green)
                        Stat(value: "2", label: "High score", color: Theme.cyan)
                        Stat(value: "£285k+", label: "Potential", color: Theme.amber)
                    }
                    if let first = store.visible.first {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text("TOP OPPORTUNITY").font(.system(size: 9, weight: .black, design: .rounded)).tracking(1).foregroundStyle(Theme.muted)
                                Spacer(); Button("VIEW ALL") { tab = 1 }.font(.system(size: 9, weight: .black)).foregroundStyle(Theme.green)
                            }
                            OpportunityRow(item: first)
                        }
                    }
                    Label("v0.1 uses demonstration projects. Live feeds come in the connected build.", systemImage: "info.circle.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Theme.amber).padding(12)
                }.padding(16).padding(.bottom, 25)
            }.background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct FeedView: View {
    @EnvironmentObject private var store: RadarStore
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 15) {
                    TitleView(top: "Bradford · 15 miles", title: "Opportunities")
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                        TextField("Search area or project", text: $store.search)
                    }.padding(13).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Category.allCases) { category in
                                Button(category.rawValue) { store.category = category }
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(store.category == category ? Color.black : Theme.muted)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(store.category == category ? Theme.green : Theme.card).clipShape(Capsule())
                            }
                        }
                    }
                    Text("\(store.visible.count) DEMO MATCHES").font(.system(size: 9, weight: .black)).tracking(1).foregroundStyle(Theme.muted)
                    ForEach(store.visible) { item in
                        NavigationLink(value: item) { OpportunityRow(item: item) }.buttonStyle(.plain)
                    }
                }.padding(16).padding(.bottom, 25)
            }
            .background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Opportunity.self) { DetailView(item: $0) }
        }
    }
}

struct SavedView: View {
    @EnvironmentObject private var store: RadarStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    TitleView(top: "Your shortlist", title: "Saved")
                    let items = store.projects.filter { store.saved.contains($0.id) }
                    if items.isEmpty {
                        Card { VStack(spacing: 12) {
                            Image(systemName: "bookmark.slash").font(.largeTitle).foregroundStyle(Theme.green)
                            Text("Nothing saved yet").font(.headline)
                            Text("Use the bookmark on a project to save it.").font(.caption).foregroundStyle(Theme.muted)
                        }.frame(maxWidth: .infinity).padding(.vertical, 35) }
                    } else {
                        ForEach(items) { item in NavigationLink(value: item) { OpportunityRow(item: item) }.buttonStyle(.plain) }
                    }
                }.padding(16)
            }
            .background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Opportunity.self) { DetailView(item: $0) }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: RadarStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TitleView(top: "Scanner configuration", title: "Settings")
                    Card { VStack(alignment: .leading, spacing: 15) {
                        Label("SEARCH AREA", systemImage: "location.fill").foregroundStyle(Theme.green).font(.caption.bold())
                        HStack { Text("Bradford, West Yorkshire").fontWeight(.bold()); Spacer(); Pill(text: "Active", color: Theme.green) }
                        HStack { Text("Radius"); Spacer(); Text("\(Int(store.radius)) miles").foregroundStyle(Theme.green) }
                        Slider(value: $store.radius, in: 5...30, step: 5).tint(Theme.green)
                    } }
                    Card { VStack(alignment: .leading, spacing: 10) {
                        Label("TRADE PROFILE", systemImage: "hammer.fill").foregroundStyle(Theme.green).font(.caption.bold())
                        Text("Roofing contractor").fontWeight(.bold())
                        Text("Extensions · Lofts · New builds").font(.caption).foregroundStyle(Theme.muted)
                    } }
                    Card { HStack {
                        VStack(alignment: .leading) { Text("High-score alerts").fontWeight(.bold()); Text(store.alerts ? "Enabled" : "Scores of 85+").font(.caption).foregroundStyle(Theme.muted) }
                        Spacer(); Button(store.alerts ? "ENABLED" : "ENABLE") { Task { await store.enableAlerts() } }.font(.caption.bold()).foregroundStyle(Theme.green)
                    } }
                    Card { VStack(alignment: .leading, spacing: 8) {
                        Label("DEMO ENGINE OPERATIONAL", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.green)
                        Label("LIVE CLOUD SCANNER NOT CONNECTED", systemImage: "clock.fill").foregroundStyle(Theme.amber)
                    }.font(.caption.bold()) }
                    Text("ZK OPPORTUNITY RADAR · v0.1.1").font(.caption2.bold()).tracking(1).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                }.padding(16)
            }.background(Theme.bg.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct DetailView: View {
    @EnvironmentObject private var store: RadarStore
    let item: Opportunity
    @State private var letter = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    Score(value: item.score)
                    VStack(alignment: .leading) { Text(item.title).font(.title2.bold()); Text("\(item.area) · \(item.postcode)").foregroundStyle(Theme.muted) }
                    Spacer(); Button { store.toggle(item) } label: { Image(systemName: store.saved.contains(item.id) ? "bookmark.fill" : "bookmark").foregroundStyle(Theme.green) }
                }
                HStack { Pill(text: item.status, color: Theme.green); Pill(text: item.age, color: Theme.cyan) }
                Card { VStack(alignment: .leading, spacing: 10) { Label("ZK ANALYSIS", systemImage: "sparkles").foregroundStyle(Theme.green); Text(item.summary).foregroundStyle(Theme.muted) } }
                HStack { Stat(value: item.value, label: "Project", color: Theme.amber); Stat(value: String(format: "%.1f mi", item.miles), label: "Distance", color: Theme.cyan) }
                Card { VStack(alignment: .leading, spacing: 9) {
                    Label("LIKELY WORK", systemImage: "hammer.fill").foregroundStyle(Theme.green)
                    ForEach(item.work, id: \.self) { Label($0, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.muted) }
                } }
                Card { VStack(alignment: .leading, spacing: 7) {
                    Label("SOURCE", systemImage: "doc.text.fill").foregroundStyle(Theme.green)
                    Text("DEMONSTRATION RECORD").font(.caption.bold()).foregroundStyle(Theme.amber)
                    Text("This is not a live homeowner lead.").font(.caption).foregroundStyle(Theme.muted)
                } }
                Button { letter = true } label: {
                    Label("CREATE INTRODUCTION LETTER", systemImage: "envelope.fill").font(.caption.bold()).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 15).background(Theme.gradient).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }.padding(16)
        }
        .background(Theme.bg.ignoresSafeArea()).navigationTitle("Opportunity").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $letter) {
            NavigationStack {
                ScrollView { Text(store.letter(item)).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .background(Theme.bg.ignoresSafeArea()).navigationTitle("Introduction Letter")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { ShareLink(item: store.letter(item)) } }
            }.presentationDetents([.medium, .large])
        }
    }
}

struct OpportunityRow: View {
    @EnvironmentObject private var store: RadarStore
    let item: Opportunity
    var body: some View {
        Card { VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                Score(value: item.score)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.system(size: 15, weight: .bold, design: .rounded)).multilineTextAlignment(.leading)
                    Text("\(item.area) · \(item.postcode) · \(String(format: "%.1f", item.miles)) mi").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(); Button { store.toggle(item) } label: { Image(systemName: store.saved.contains(item.id) ? "bookmark.fill" : "bookmark").foregroundStyle(Theme.green) }.buttonStyle(.plain)
            }
            HStack { Pill(text: item.status, color: item.status == "Approved" ? Theme.green : Theme.cyan); Spacer(); Text(item.age).font(.caption2).foregroundStyle(Theme.muted) }
            Divider().overlay(Theme.border)
            HStack { Text(item.value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(Theme.amber); Spacer(); Image(systemName: "chevron.right").foregroundStyle(Theme.green) }
        } }
    }
}

struct RadarAnimation: View {
    @State private var turn = 0.0
    @State private var pulse = false
    var body: some View {
        ZStack {
            ForEach([0.35, 0.6, 0.82, 1.0], id: \.self) { Circle().stroke(Theme.green.opacity(0.18)).scaleEffect($0) }
            Rectangle().fill(Theme.green.opacity(0.12)).frame(width: 1)
            Rectangle().fill(Theme.green.opacity(0.12)).frame(height: 1)
            Circle().trim(from: 0, to: 0.22).stroke(AngularGradient(colors: [.clear, Theme.green], center: .center), style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(turn)).shadow(color: Theme.green, radius: 10)
            Circle().fill(Theme.green).frame(width: 9, height: 9).offset(x: 70, y: -58).scaleEffect(pulse ? 1.4 : 0.8).shadow(color: Theme.green, radius: 9)
            Circle().fill(Theme.cyan).frame(width: 7, height: 7).offset(x: -73, y: 35).shadow(color: Theme.cyan, radius: 8)
            VStack { Text("15 MI").font(.title3.bold()); Text("BRADFORD").font(.caption2.bold()).tracking(1).foregroundStyle(Theme.green) }
                .padding(16).background(Theme.bg.opacity(0.94)).clipShape(Circle()).overlay(Circle().stroke(Theme.green.opacity(0.5)))
        }
        .padding(10)
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { turn = 360 }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.padding(15).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border)) }
}

struct Pill: View {
    let text: String
    let color: Color
    var body: some View { HStack(spacing: 5) { Circle().fill(color).frame(width: 6, height: 6); Text(text.uppercased()).font(.system(size: 8, weight: .black, design: .rounded)) }.foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 6).background(color.opacity(0.1)).clipShape(Capsule()) }
}

struct Score: View {
    let value: Int
    var color: Color { value >= 85 ? Theme.green : Theme.amber }
    var body: some View { VStack(spacing: 0) { Text("\(value)").font(.system(size: 18, weight: .black)); Text("SCORE").font(.system(size: 6, weight: .black)) }.foregroundStyle(color).frame(width: 48, height: 48).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12)) }
}

struct Stat: View {
    let value, label: String
    let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 3) { Text(value).font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1); Text(label.uppercased()).font(.system(size: 7, weight: .black)).foregroundStyle(Theme.muted) }.frame(maxWidth: .infinity, alignment: .leading).padding(11).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.border)) }
}

struct TitleView: View {
    let top, title: String
    var body: some View { VStack(alignment: .leading, spacing: 4) { Text(top.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(Theme.green); Text(title).font(.system(size: 29, weight: .black, design: .rounded)) } }
}
