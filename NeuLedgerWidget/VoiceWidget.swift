// NeuLedgerWidget/VoiceWidget.swift
import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct VoiceTimelineEntry: TimelineEntry {
    let date: Date
    let accountName: String
}

// MARK: - Timeline Provider

struct VoiceTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoiceTimelineEntry {
        VoiceTimelineEntry(date: .now, accountName: "現金帳戶")
    }

    func getSnapshot(in context: Context, completion: @escaping (VoiceTimelineEntry) -> Void) {
        completion(VoiceTimelineEntry(date: .now, accountName: "現金帳戶"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceTimelineEntry>) -> Void) {
        let entry = VoiceTimelineEntry(date: .now, accountName: "現金帳戶")
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Widget View

struct VoiceWidgetView: View {
    let entry: VoiceTimelineEntry

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.orange)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
                .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)

            Text("widget_voice_title")
                .font(.system(size: 12, weight: .semibold))

            Text(entry.accountName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Definition (NOT registered in WidgetBundle — Phase 2)

struct VoiceWidget: Widget {
    let kind: String = "VoiceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoiceTimelineProvider()) { entry in
            VoiceWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("widget_voice_display_name"))
        .description(Text("widget_voice_description"))
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    VoiceWidget()
} timeline: {
    VoiceTimelineEntry(date: .now, accountName: "現金帳戶")
}
