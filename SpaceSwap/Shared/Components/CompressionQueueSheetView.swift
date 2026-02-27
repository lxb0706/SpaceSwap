//
//  CompressionQueueSheetView.swift
//  SpaceSwap
//
//  Created by Codex on 2026/2/26.
//

import SwiftUI

struct CompressionQueueSheetView: View {
    @ObservedObject var queueManager: CompressionQueueManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Queue Summary") {
                    HStack {
                        Text("Running")
                        Spacer()
                        Text("\(queueManager.runningCount)/\(queueManager.maxConcurrentTasks)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Waiting")
                        Spacer()
                        Text("\(queueManager.waitingCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tasks") {
                    if queueManager.queueSnapshot.isEmpty {
                        Text("No compression tasks yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(queueManager.queueSnapshot) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(entry.filename)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(entry.status.displayText)
                                        .font(.caption)
                                        .foregroundStyle(statusColor(entry.status))
                                }

                                if entry.status == .queued || entry.status == .running {
                                    ProgressView(value: entry.progress)
                                        .progressViewStyle(.linear)
                                    Text("\(Int(entry.progress * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else if let message = entry.errorMessage, !message.isEmpty {
                                    Text(message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Compression Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statusColor(_ status: CompressionQueueStatus) -> Color {
        switch status {
        case .queued:
            return .orange
        case .running:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
}
