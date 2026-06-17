import Foundation
import GRDB
import com_awareframework_ios_core

public struct ProcessorData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1
    public static let databaseTableName = "ios_processor"
    public static let TABLE_NAME = databaseTableName

    public var appCpuUsage: Double = -1
    public var activeProcessorCount: Int = 0
    public var processorCount: Int = 0
    public var residentMemory: Int64 = -1
    public var physicalMemory: Int64 = -1
    public var memoryUsage: Double = -1
    public var systemUptime: Double = 0
    public var thermalState: Int = -1
    public var lowPowerMode: Int = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp = dict["timestamp"] as? Int64 ?? 0
        label = dict["label"] as? String ?? ""
        deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        appCpuUsage = dict["appCpuUsage"] as? Double ?? -1
        activeProcessorCount = dict["activeProcessorCount"] as? Int ?? 0
        processorCount = dict["processorCount"] as? Int ?? 0
        residentMemory = dict["residentMemory"] as? Int64 ?? -1
        physicalMemory = dict["physicalMemory"] as? Int64 ?? -1
        memoryUsage = dict["memoryUsage"] as? Double ?? -1
        systemUptime = dict["systemUptime"] as? Double ?? 0
        thermalState = dict["thermalState"] as? Int ?? -1
        lowPowerMode = dict["lowPowerMode"] as? Int ?? 0
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("label", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("os", .text).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("appCpuUsage", .double).notNull()
                t.column("activeProcessorCount", .integer).notNull()
                t.column("processorCount", .integer).notNull()
                t.column("residentMemory", .integer).notNull()
                t.column("physicalMemory", .integer).notNull()
                t.column("memoryUsage", .double).notNull()
                t.column("systemUptime", .double).notNull()
                t.column("thermalState", .integer).notNull()
                t.column("lowPowerMode", .integer).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "timezone": timezone,
            "os": os,
            "jsonVersion": jsonVersion,
            "appCpuUsage": appCpuUsage,
            "activeProcessorCount": activeProcessorCount,
            "processorCount": processorCount,
            "residentMemory": residentMemory,
            "physicalMemory": physicalMemory,
            "memoryUsage": memoryUsage,
            "systemUptime": systemUptime,
            "thermalState": thermalState,
            "lowPowerMode": lowPowerMode,
        ]
    }
}
