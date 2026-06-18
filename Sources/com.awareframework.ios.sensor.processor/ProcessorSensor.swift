//
//  ProcessorSensor.swift
//  com.awareframework.ios.sensor.processor
//

import Darwin
import Foundation
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareProcessor = Notification.Name(ProcessorSensor.ACTION_AWARE_PROCESSOR)
    public static let actionAwareProcessorStart = Notification.Name(ProcessorSensor.ACTION_AWARE_PROCESSOR_START)
    public static let actionAwareProcessorStop = Notification.Name(ProcessorSensor.ACTION_AWARE_PROCESSOR_STOP)
    public static let actionAwareProcessorSync = Notification.Name(ProcessorSensor.ACTION_AWARE_PROCESSOR_SYNC)
    public static let actionAwareProcessorSetLabel = Notification.Name(ProcessorSensor.ACTION_AWARE_PROCESSOR_SET_LABEL)
    public static let actionAwareProcessorSyncCompletion = Notification.Name(ProcessorSensor.ACTION_AWARE_PROCESSOR_SYNC_COMPLETION)
}

public protocol ProcessorObserver {
    func onProcessorChanged(data: ProcessorData)
}

extension ProcessorSensor {
    public static let TAG = "AWARE::Processor"
    public static let ACTION_AWARE_PROCESSOR = "com.awareframework.ios.sensor.processor"
    public static let ACTION_AWARE_PROCESSOR_START = "com.awareframework.ios.sensor.processor.SENSOR_START"
    public static let ACTION_AWARE_PROCESSOR_STOP = "com.awareframework.ios.sensor.processor.SENSOR_STOP"
    public static let ACTION_AWARE_PROCESSOR_SET_LABEL = "com.awareframework.ios.sensor.processor.SET_LABEL"
    public static let ACTION_AWARE_PROCESSOR_SYNC = "com.awareframework.ios.sensor.processor.SENSOR_SYNC"
    public static let ACTION_AWARE_PROCESSOR_SYNC_COMPLETION = "com.awareframework.ios.sensor.processor.SENSOR_SYNC_COMPLETION"
    public static let EXTRA_DATA = "data"
    public static let EXTRA_LABEL = "label"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
}

public class ProcessorSensor: AwareSensor {
    public var CONFIG = Config()
    private var timer: DispatchSourceTimer?
    private let sampleQueue = DispatchQueue(
        label: "com.awareframework.ios.sensor.processor.sample.queue",
        qos: .utility)

    public class Config: SensorConfig {
        public var sensorObserver: ProcessorObserver?
        public var sampleIntervalSeconds: Int = 60 {
            didSet {
                if sampleIntervalSeconds <= 0 {
                    if debug {
                        print(
                            ProcessorSensor.TAG,
                            "The sampleIntervalSeconds parameter must be greater than 0. Keeping \(oldValue).")
                    }
                    sampleIntervalSeconds = oldValue
                }
            }
        }

        public override init() {
            super.init()
            dbPath = "aware_processor"
        }

        public convenience init(_ config: Dictionary<String, Any>) {
            self.init()
            set(config: config)
            if let sampleIntervalSeconds = config["sampleIntervalSeconds"] as? Int {
                self.sampleIntervalSeconds = sampleIntervalSeconds
            }
        }

        public func apply(closure: (_ config: ProcessorSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public override convenience init() {
        self.init(ProcessorSensor.Config())
    }

    public init(_ config: ProcessorSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { config in
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.processor.sync.queue")
        }
    }

    deinit {
        stopTimer()
    }

    public override func start() {
        stopTimer()
        sampleQueue.async { [weak self] in
            self?.sample()
        }

        let timer = DispatchSource.makeTimerSource(queue: sampleQueue)
        timer.schedule(
            deadline: .now() + .seconds(max(1, CONFIG.sampleIntervalSeconds)),
            repeating: .seconds(max(1, CONFIG.sampleIntervalSeconds)))
        timer.setEventHandler { [weak self] in
            self?.sample()
        }
        timer.resume()
        self.timer = timer
        notificationCenter.post(name: .actionAwareProcessorStart, object: self)
    }

    public override func stop() {
        stopTimer()
        notificationCenter.post(name: .actionAwareProcessorStop, object: self)
    }

    public override func sync(force: Bool = false) {
        guard let engine = dbEngine, let syncConfig = syncConfig else { return }
        syncConfig.debug = CONFIG.debug
        syncConfig.completionHandler = { status, error in
            var userInfo: Dictionary<String, Any> = [ProcessorSensor.EXTRA_STATUS: status]
            if let error {
                userInfo[ProcessorSensor.EXTRA_ERROR] = error
            }
            self.notificationCenter.post(
                name: .actionAwareProcessorSyncCompletion,
                object: self,
                userInfo: userInfo)
        }
        engine.startSync(syncConfig)
        notificationCenter.post(name: .actionAwareProcessorSync, object: self)
    }

    public override func set(label: String) {
        CONFIG.label = label
        notificationCenter.post(
            name: .actionAwareProcessorSetLabel,
            object: self,
            userInfo: [ProcessorSensor.EXTRA_LABEL: label])
    }

    public func sample() {
        var data = ProcessorData()
        data.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        data.label = CONFIG.label

        let processInfo = ProcessInfo.processInfo
        data.appCpuUsage = Self.currentAppCPUUsage()
        data.activeProcessorCount = processInfo.activeProcessorCount
        data.processorCount = processInfo.processorCount
        data.physicalMemory = Self.clampedInt64(processInfo.physicalMemory)
        data.residentMemory = Self.currentResidentMemory()
        if data.physicalMemory > 0, data.residentMemory >= 0 {
            data.memoryUsage = Double(data.residentMemory) / Double(data.physicalMemory) * 100
        }
        data.systemUptime = processInfo.systemUptime
        data.thermalState = Self.thermalStateValue(processInfo.thermalState)
        if #available(iOS 9.0, macOS 12.0, *) {
            data.lowPowerMode = processInfo.isLowPowerModeEnabled ? 1 : 0
        } else {
            data.lowPowerMode = 0
        }

        dbEngine?.save([data])
        CONFIG.sensorObserver?.onProcessorChanged(data: data)
        notificationCenter.post(
            name: .actionAwareProcessor,
            object: self,
            userInfo: [ProcessorSensor.EXTRA_DATA: data])
    }

    private func stopTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private static func currentAppCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threadList else {
            return -1
        }
        defer {
            let size = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), size)
        }

        var usage = 0.0
        for index in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let infoResult = withUnsafeMutablePointer(to: &threadInfo) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                    reboundPointer in
                    thread_info(
                        threadList[index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        reboundPointer,
                        &threadInfoCount)
                }
            }
            guard infoResult == KERN_SUCCESS else { continue }
            if (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                usage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }
        return usage
    }

    private static func currentResidentMemory() -> Int64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return -1
        }
        return clampedInt64(info.phys_footprint)
    }

    private static func clampedInt64(_ value: UInt64) -> Int64 {
        Int64(min(value, UInt64(Int64.max)))
    }

    private static func thermalStateValue(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal:
            return 0
        case .fair:
            return 1
        case .serious:
            return 2
        case .critical:
            return 3
        @unknown default:
            return -1
        }
    }
}
