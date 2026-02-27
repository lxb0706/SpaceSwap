//
//  HistoryView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var recordPendingDeleteOriginal: CompressionRecord?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary Section
                if !viewModel.compressionRecords.isEmpty {
                    VStack(spacing: 16) {
                        Text("Compression History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 32) {
                            VStack(spacing: 4) {
                                Text("\(viewModel.totalCompressionCount)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("Videos Compressed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Text(viewModel.totalSpaceSaved.formattedBytes)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Text("Space Saved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                
                // History List
                if viewModel.isLoading {
                    ProgressView("Loading history...")
                        .padding()
                } else if viewModel.compressionRecords.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No compression history yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Compress some videos to see your history here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.compressionRecords.sorted { $0.date > $1.date }) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Video Compressed")
                                            .font(.headline)
                                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Menu {
                                        if record.status == 1 && !record.isAssetDeleted {
                                            Button(role: .destructive) {
                                                recordPendingDeleteOriginal = record
                                            } label: {
                                                Label("Delete Original", systemImage: "trash")
                                            }
                                        }

                                        Button(role: .destructive) {
                                            viewModel.deleteRecord(record)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Original")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(record.originalSize.formattedBytes)
                                            .font(.subheadline)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Compressed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(record.compressedSize.formattedBytes)
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Saved")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text((record.originalSize - record.compressedSize).formattedBytes)
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Text("Quality: \(record.quality)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if record.isAssetDeleted {
                                    Text("Original Deleted")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if record.status == 1 {
                                    Button(role: .destructive) {
                                        recordPendingDeleteOriginal = record
                                    } label: {
                                        Text("Delete Original")
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let record = viewModel.compressionRecords.sorted { $0.date > $1.date }[index]
                                viewModel.deleteRecord(record)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.compressionRecords.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                viewModel.clearAllHistory()
                            } label: {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil), actions: {
                Button("OK") {
                    viewModel.error = nil
                }
            }, message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            })
            .refreshable {
                viewModel.loadHistory()
            }
        }
        .alert(
            "Delete Original?",
            isPresented: Binding(
                get: { recordPendingDeleteOriginal != nil },
                set: { isPresented in
                    if !isPresented {
                        recordPendingDeleteOriginal = nil
                    }
                }
            ),
            actions: {
                Button("Cancel", role: .cancel) {
                    recordPendingDeleteOriginal = nil
                }
                Button("Delete", role: .destructive) {
                    guard let recordPendingDeleteOriginal else { return }
                    viewModel.deleteOriginal(for: recordPendingDeleteOriginal)
                    self.recordPendingDeleteOriginal = nil
                }
            },
            message: {
                Text("This will move the original video to Recently Deleted.")
            }
        )
    }
}
