import XCTest
import com_awareframework_ios_core
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

    /// The sensor creates its own table: rows can be saved and read back for sync without the app
    /// creating the table (it used to be missing, so every save failed and nothing was synced)
    func testSensorCreatesItsTable() {
        let sensor = ProcessorSensor(ProcessorSensor.Config().apply { config in
            config.dbPath = "create_table_test_\(UUID().uuidString)"
        })
        XCTAssertEqual(sensor.CONFIG.dbTableName, ProcessorData.databaseTableName)
        guard let engine = sensor.dbEngine else { return XCTFail("no engine") }
        let saved = expectation(description: "saved")
        engine.save([ProcessorData()]) { error in
            XCTAssertNil(error)
            saved.fulfill()
        }
        wait(for: [saved], timeout: 5)
        XCTAssertEqual(engine.count(filter: nil), 1)
        XCTAssertEqual(engine.fetch(filter: nil, limit: nil)?.count, 1, "rows can be read for sync")
    }
}
