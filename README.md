# AWARE: Processor

The processor sensor samples app process resource usage and device processor state on iOS.
It is designed for periodic, low-overhead monitoring of the AwareClient process, not for
system-wide CPU profiling.

Records are stored in `ios_processor` under the `aware_processor.sqlite` database.

## Installation

Add the package to your app target:

```text
https://github.com/awareframework/com.awareframework.ios.sensor.processor.git
```

Then import the module:

```swift
import com_awareframework_ios_sensor_processor
```

## Example Usage

```swift
let sensor = ProcessorSensor(ProcessorSensor.Config().apply { config in
    config.sampleIntervalSeconds = 60
})

sensor.start()
```

To stop collection:

```swift
sensor.stop()
```

### ProcessorSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sampleIntervalSeconds: Int`: Sampling interval in seconds. Values less than `1` are ignored. (default = `60`)
+ `sensorObserver: ProcessorObserver?`: Callback for live processor samples. (default = `nil`)
+ `dbPath: String`: SQLite database path stem. (default = `"aware_processor"`)
+ `dbTableName: String?`: Active database table name. (default = `"ios_processor"` in AwareClient)

## Data Representations

`ProcessorData` stores the following fields:

| Field | Type | Description |
| --- | --- | --- |
| `timestamp` | `Int64` | Unix timestamp in milliseconds. |
| `deviceId` | `String` | AWARE device identifier. |
| `label` | `String` | Optional sensor label. |
| `appCpuUsage` | `Double` | CPU usage percentage for the current app process. |
| `activeProcessorCount` | `Int` | Number of active logical processors. |
| `processorCount` | `Int` | Total number of logical processors. |
| `residentMemory` | `Int64` | Current app memory footprint in bytes. |
| `physicalMemory` | `Int64` | Device physical memory in bytes. |
| `memoryUsage` | `Double` | App memory footprint as a percentage of physical memory. |
| `systemUptime` | `Double` | System uptime in seconds. |
| `thermalState` | `Int` | `0` nominal, `1` fair, `2` serious, `3` critical, `-1` unknown. |
| `lowPowerMode` | `Int` | `1` when Low Power Mode is enabled, otherwise `0`. |

## Broadcasts

| Notification | Description |
| --- | --- |
| `actionAwareProcessorStart` | Posted when the sensor starts. |
| `actionAwareProcessorStop` | Posted when the sensor stops. |
| `actionAwareProcessor` | Posted after each processor sample. |
| `actionAwareProcessorSync` | Posted when sync starts. |
| `actionAwareProcessorSyncCompletion` | Posted when sync completes. |
| `actionAwareProcessorSetLabel` | Posted when the label changes. |

## Observer

```swift
final class Observer: ProcessorObserver {
    func onProcessorChanged(data: ProcessorData) {
        print(data.toDictionary())
    }
}

let config = ProcessorSensor.Config().apply { config in
    config.sampleIntervalSeconds = 30
    config.sensorObserver = Observer()
}

let sensor = ProcessorSensor(config)
sensor.start()
```
