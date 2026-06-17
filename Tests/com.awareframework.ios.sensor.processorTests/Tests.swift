import XCTest
import GRDB
@testable import com_awareframework_ios_sensor_processor

final class ProcessorSensorTests: XCTestCase {
    func testProcessorDataDictionaryContainsMetrics() {
        var data = ProcessorData()
        data.timestamp = 123
        data.appCpuUsage = 12.5
        data.residentMemory = 1024
        data.physicalMemory = 2048
        data.memoryUsage = 50

        let dictionary = data.toDictionary()

        XCTAssertEqual(dictionary["timestamp"] as? Int64, 123)
        XCTAssertEqual(dictionary["appCpuUsage"] as? Double, 12.5)
        XCTAssertEqual(dictionary["residentMemory"] as? Int64, 1024)
        XCTAssertEqual(dictionary["memoryUsage"] as? Double, 50)
    }

    func testCreateTable() throws {
        let queue = try DatabaseQueue()
        try ProcessorData.createTable(queue: queue)
        let exists = try queue.read { db in
            try db.tableExists(ProcessorData.databaseTableName)
        }
        XCTAssertTrue(exists)
    }
}
