//
//  CompressionPlaybackViewModel.swift
//  SpaceSwap
//
//  Created by Codex on 2026/2/26.
//

import AVFoundation
import Combine
import Foundation
import Photos

@MainActor
final class CompressionPlaybackViewModel: ObservableObject {
    @Published var isReady = false
    @Published var isPlaying = false
    @Published var isScrubbing = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var loadErrorMessage: String?

    let player = AVPlayer()

    private var requestID: PHImageRequestID?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var shouldResumeAfterSeek = false

    init(asset: PHAsset) {
        player.automaticallyWaitsToMinimizeStalling = true
        loadPlayerItem(for: asset)
    }

    deinit {
        if let requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func beginScrubbing() {
        isScrubbing = true
        shouldResumeAfterSeek = isPlaying
        pause()
    }

    func updateScrubbingTime(_ time: Double) {
        currentTime = min(max(time, 0), max(duration, 0))
    }

    func endScrubbing() {
        seek(to: currentTime, resume: shouldResumeAfterSeek)
    }

    func formattedTime(_ time: Double) -> String {
        guard time.isFinite, time > 0 else { return "00:00" }
        let totalSeconds = Int(time.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func loadPlayerItem(for asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.version = .current

        requestID = PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self] item, info in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.requestID = nil

                if let item {
                    self.configurePlayerItem(item)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    self.loadErrorMessage = error.localizedDescription
                } else if (info?[PHImageCancelledKey] as? Bool) == true {
                    self.loadErrorMessage = "Video load cancelled."
                } else {
                    self.loadErrorMessage = "Unable to load video."
                }
            }
        }
    }

    private func configurePlayerItem(_ item: AVPlayerItem) {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player.replaceCurrentItem(with: item)
        let itemDuration = item.duration.seconds
        duration = itemDuration.isFinite ? itemDuration : 0
        currentTime = 0
        isReady = true
        loadErrorMessage = nil

        observePlaybackTime()
        observePlaybackEnd(item: item)
        play()
    }

    private func observePlaybackTime() {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isScrubbing else { return }
                self.currentTime = max(0, time.seconds)
                if let currentItemDuration = self.player.currentItem?.duration.seconds, currentItemDuration.isFinite {
                    self.duration = currentItemDuration
                }
                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }
    }

    private func observePlaybackEnd(item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.seek(to: 0, resume: true)
            }
        }
    }

    private func seek(to targetTime: Double, resume: Bool) {
        let clamped = min(max(targetTime, 0), max(duration, 0))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isScrubbing = false
                self.currentTime = clamped
                if resume {
                    self.play()
                }
            }
        }
    }
}
