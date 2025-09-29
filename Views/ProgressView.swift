import SwiftUI
import SwiftData
// import Charts  // Uncomment if you add SwiftUI Charts later

struct ProgressView: View {
    @Query(sort: \ResponseRecord.timestamp) private var records: [ResponseRecord]
    
    private var weeklyStats: [Stat] { stats(forDays: 7) }
    private var monthlyStats: [Stat] { stats(forDays: 30) }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Last 7 Days") {
                    ForEach(weeklyStats) { row in
                        HStack {
                            Text(row.question)
                            Spacer()
                            SwiftUI.ProgressView(value: row.completionRate)
                                .progressViewStyle(.linear)
                                .frame(width: 120)
                            Text("\(Int(row.completionRate*100))%")
                                .font(.caption)
                        }
                    }
                }
                Section("Last 30 Days") {
                    ForEach(monthlyStats) { row in
                        HStack {
                            Text(row.question)
                            Spacer()
                            SwiftUI.ProgressView(value: row.completionRate)
                                .progressViewStyle(.linear)
                                .frame(width: 120)
                            Text("\(Int(row.completionRate*100))%")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
    
    // MARK: – Helpers
    private func stats(forDays days: Int) -> [Stat] {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let filtered = records.filter { $0.timestamp >= since }
        var grouped: [UUID: (question:String, total:Int, completed:Int)] = [:]
        for rec in filtered {
            var entry = grouped[rec.reminderID] ?? (rec.reminderQuestion,0,0)
            entry.total += 1
            if rec.didComplete { entry.completed += 1 }
            grouped[rec.reminderID] = entry
        }
        return grouped.values.map { Stat(question:$0.question, rate: $0.total==0 ? 0 : Double($0.completed)/Double($0.total)) }
            .sorted { $0.question < $1.question }
    }
    
    private struct Stat: Identifiable { let id = UUID(); let question: String; let completionRate: Double; init(question:String, rate:Double){self.question=question; self.completionRate=rate} }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ResponseRecord.self, configurations: config)
    ProgressView().modelContainer(container)
} 