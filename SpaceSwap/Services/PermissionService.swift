//
//  PermissionService.swift
//  SpaceSwap
//
//  Created by 连晓彬 on 2026/2/9.
//

import Photos
import Combine

protocol PermissionServiceProtocol {
    var authorizationStatus: PHAuthorizationStatus { get }
    var authorizationStatusPublisher: AnyPublisher<PHAuthorizationStatus, Never> { get }
    func requestAuthorization() async -> PHAuthorizationStatus
}

final class PermissionService: PermissionServiceProtocol {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    var authorizationStatusPublisher: AnyPublisher<PHAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }
    
    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }
}