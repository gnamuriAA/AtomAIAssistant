//
//  NetworkManager.swift
//  AtomAIAssistant
//
//  Created by Gowtham, Namuru on 16/02/26.
//

import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var interfaceType: NWInterface.InterfaceType? = nil

    private init() {
        // Seed with initial state after startMonitoring() is called
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // Compute values from path
            let connected = (path.status == .satisfied)
            let iface = path.availableInterfaces
                .first(where: { path.usesInterfaceType($0.type) })?.type

            // Publish on main to keep SwiftUI happy
            DispatchQueue.main.async {
                self.isConnected = connected
                self.interfaceType = iface
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
}
