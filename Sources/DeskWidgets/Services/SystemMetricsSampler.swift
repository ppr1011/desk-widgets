import Foundation
import Darwin
import Darwin.Mach
import Combine

/// 系统指标采集器(单例)。定时采样 CPU / 内存 / 网速,供系统监控组件订阅。
final class SystemMetricsSampler: ObservableObject {
    static let shared = SystemMetricsSampler()

    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var memoryTotal: UInt64 = 0
    @Published private(set) var downloadSpeed: Double = 0
    @Published private(set) var uploadSpeed: Double = 0

    private var timer: Timer?
    private var subscriberCount = 0
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var previousNetworkBytes: (rx: UInt64, tx: UInt64)?
    private var previousSampleTime: Date?

    private init() {}

    /// 组件视图出现时订阅;引用计数归零后停止采样,避免无组件时空转。
    func addSubscriber() {
        subscriberCount += 1
        if subscriberCount == 1 {
            start()
        }
    }

    func removeSubscriber() {
        subscriberCount = max(0, subscriberCount - 1)
        if subscriberCount == 0 {
            stop()
        }
    }

    private func start() {
        previousCPUTicks = readCPUTicks()
        previousNetworkBytes = readNetworkBytes()
        previousSampleTime = Date()
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        previousCPUTicks = nil
        previousNetworkBytes = nil
        previousSampleTime = nil
    }

    private func sample() {
        let now = Date()
        let interval = max(now.timeIntervalSince(previousSampleTime ?? now), 0.001)

        if let currentTicks = readCPUTicks(), let previous = previousCPUTicks {
            let user = Double(currentTicks.user &- previous.user)
            let system = Double(currentTicks.system &- previous.system)
            let idle = Double(currentTicks.idle &- previous.idle)
            let nice = Double(currentTicks.nice &- previous.nice)
            let total = user + system + idle + nice
            cpuUsage = total > 0 ? ((user + system + nice) / total) * 100 : 0
            previousCPUTicks = currentTicks
        }

        let mem = readMemory()
        memoryUsed = mem.used
        memoryTotal = mem.total

        if let currentNet = readNetworkBytes(), let previous = previousNetworkBytes {
            let rxDelta = Double(currentNet.rx &- previous.rx)
            let txDelta = Double(currentNet.tx &- previous.tx)
            downloadSpeed = rxDelta / interval
            uploadSpeed = txDelta / interval
            previousNetworkBytes = currentNet
        }

        previousSampleTime = now
    }

    private func readCPUTicks() -> (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? {
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        var cpuLoad = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return (
            user: cpuLoad.cpu_ticks.0,
            system: cpuLoad.cpu_ticks.1,
            idle: cpuLoad.cpu_ticks.2,
            nice: cpuLoad.cpu_ticks.3
        )
    }

    private func readMemory() -> (used: UInt64, total: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return (used: 0, total: total)
        }
        let usedPages = stats.active_count
            + stats.wire_count
            + stats.compressor_page_count
        return (used: UInt64(usedPages) * pageSize, total: total)
    }

    private func readNetworkBytes() -> (rx: UInt64, tx: UInt64)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp, !isLoopback, let data = current.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self)
                rx &+= UInt64(ifData.pointee.ifi_ibytes)
                tx &+= UInt64(ifData.pointee.ifi_obytes)
            }
            ptr = current.pointee.ifa_next
        }
        return (rx: rx, tx: tx)
    }
}
