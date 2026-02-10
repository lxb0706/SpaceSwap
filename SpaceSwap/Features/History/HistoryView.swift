//
//  HistoryView.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    
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
    }
}