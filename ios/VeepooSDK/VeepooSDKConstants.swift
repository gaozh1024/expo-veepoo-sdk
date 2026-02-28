import Foundation

enum VeepooEvent {
  static let deviceFound = "deviceFound"
  static let deviceConnected = "deviceConnected"
  static let deviceDisconnected = "deviceDisconnected"
  static let deviceConnectStatus = "deviceConnectStatus"
  static let deviceReady = "deviceReady"
  static let bluetoothStateChanged = "bluetoothStateChanged"
  static let deviceFunction = "deviceFunction"
  static let deviceVersion = "deviceVersion"
  static let passwordData = "passwordData"
  static let batteryData = "batteryData"
  static let heartRateTestResult = "heartRateTestResult"
  static let bloodPressureTestResult = "bloodPressureTestResult"
  static let bloodOxygenTestResult = "bloodOxygenTestResult"
  static let temperatureTestResult = "temperatureTestResult"
  static let stressData = "stressData"
  static let bloodGlucoseData = "bloodGlucoseData"
  static let sleepData = "sleepData"
  static let sportStepData = "sportStepData"
  static let readOriginProgress = "readOriginProgress"
  static let readOriginComplete = "readOriginComplete"
  static let originFiveMinuteData = "originFiveMinuteData"
  static let originHalfHourData = "originHalfHourData"
  static let originSpo2Data = "originSpo2Data"
  static let error = "error"
}

let DEVICE_FOUND = VeepooEvent.deviceFound
let DEVICE_CONNECTED = VeepooEvent.deviceConnected
let DEVICE_DISCONNECTED = VeepooEvent.deviceDisconnected
let DEVICE_CONNECT_STATUS = VeepooEvent.deviceConnectStatus
let DEVICE_READY = VeepooEvent.deviceReady
let BLUETOOTH_STATE_CHANGED = VeepooEvent.bluetoothStateChanged
let DEVICE_FUNCTION = VeepooEvent.deviceFunction
let DEVICE_VERSION = VeepooEvent.deviceVersion
let PASSWORD_DATA = VeepooEvent.passwordData
let BATTERY_DATA = VeepooEvent.batteryData
let HEART_RATE_TEST_RESULT = VeepooEvent.heartRateTestResult
let BLOOD_PRESSURE_TEST_RESULT = VeepooEvent.bloodPressureTestResult
let BLOOD_OXYGEN_TEST_RESULT = VeepooEvent.bloodOxygenTestResult
let TEMPERATURE_TEST_RESULT = VeepooEvent.temperatureTestResult
let STRESS_DATA = VeepooEvent.stressData
let BLOOD_GLUCOSE_DATA = VeepooEvent.bloodGlucoseData
let SLEEP_DATA = VeepooEvent.sleepData
let SPORT_STEP_DATA = VeepooEvent.sportStepData
let READ_ORIGIN_PROGRESS = VeepooEvent.readOriginProgress
let READ_ORIGIN_COMPLETE = VeepooEvent.readOriginComplete
let ORIGIN_FIVE_MINUTE_DATA = VeepooEvent.originFiveMinuteData
let ORIGIN_HALF_HOUR_DATA = VeepooEvent.originHalfHourData
let ORIGIN_SPO2_DATA = VeepooEvent.originSpo2Data
let ERROR = VeepooEvent.error
