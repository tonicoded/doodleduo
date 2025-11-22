//
//  LatestDoodleWidget.swift
//  LatestDoodleWidget
//

import WidgetKit
import SwiftUI

struct LatestDoodleEntry: TimelineEntry {
    let date: Date
    let snapshot: DoodleWidgetSnapshot?
}

struct LatestDoodleProvider: TimelineProvider {
    func placeholder(in context: Context) -> LatestDoodleEntry {
        LatestDoodleEntry(date: Date(), snapshot: .placeholder)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LatestDoodleEntry) -> Void) {
        let entry = LatestDoodleEntry(date: Date(), snapshot: DoodleWidgetStore.shared.loadLatestDoodle())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestDoodleEntry>) -> Void) {
        let snapshot = DoodleWidgetStore.shared.loadLatestDoodle()
        print("🎨 Widget getTimeline - snapshot loaded: \(snapshot != nil ? "Yes" : "No")")
        if let snapshot = snapshot {
            print("🎨 Widget snapshot details: sender=\(snapshot.senderName), date=\(snapshot.updatedAt), isFromPartner=\(snapshot.isFromPartner)")
        }
        let currentEntry = LatestDoodleEntry(date: Date(), snapshot: snapshot)
        
        // iOS limits widget updates to preserve battery life
        // Use smart refresh intervals based on user engagement patterns
        let refreshInterval: TimeInterval = context.isPreview ? 60 : 300 // 5 minutes for live widgets
        let _ = Date().addingTimeInterval(refreshInterval)
        
        // Create timeline entries with decreasing frequency
        var entries: [LatestDoodleEntry] = [currentEntry]
        
        // Add a few more entries with longer intervals for better system optimization
        let intervals: [TimeInterval] = [300, 900, 1800] // 5min, 15min, 30min
        for interval in intervals {
            let futureDate = Date().addingTimeInterval(interval)
            entries.append(LatestDoodleEntry(date: futureDate, snapshot: snapshot))
        }
        
        // Use .atEnd policy - iOS will request new timeline when appropriate
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct LatestDoodleWidgetEntryView: View {
    var entry: LatestDoodleEntry

    private var image: Image? {
        guard let data = entry.snapshot?.imageData,
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack {
                    Spacer()
                    HStack {
                        if let snapshot = entry.snapshot {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snapshot.senderName.capitalized)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                Text(snapshot.updatedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .fill(.black.opacity(0.1))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(.white.opacity(0.4))
                                .font(.title2)
                            Text("No doodles yet")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    )
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.black.opacity(0.1), Color.gray.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

@main
struct LatestDoodleWidgetBundle: WidgetBundle {
    var body: some Widget {
        LatestDoodleWidget()
    }
}

struct LatestDoodleWidget: Widget {
    let kind: String = "LatestDoodleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LatestDoodleProvider()) { entry in
            LatestDoodleWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemLarge])
        .configurationDisplayName("Latest doodle")
        .description("See your partner's latest doodle right on the Home Screen.")
    }
}
