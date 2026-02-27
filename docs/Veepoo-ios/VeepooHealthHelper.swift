import Foundation
import React

/// Veepoo 健康数据助手
///
/// 职责：
/// - 读取和解析 Veepoo 设备的健康数据
/// - 支持原始数据（5分钟粒度）、睡眠数据、计步数据
/// - 处理全量数据同步流程
class VeepooHealthHelper {
    
    // MARK: - Properties
    
    /// 事件回调闭包
    /// - Parameters:
    ///   - eventName: 事件名称（如 "VeepooReadDataProgress"）
    ///   - body: 事件参数字典
    var onEvent: ((String, [String: Any]?) -> Void)?
    
    /// 读取原始健康数据（5分钟粒度）
    /// 包含心率、血压、血氧、体温等详细数据点。
    /// - Parameter dayOffset: 0 表示今天，-1 表示昨天，以此类推
    func readOriginData(_ dayOffset: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve([])
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let deviceAddress = manager.peripheralModel?.deviceAddress else {
                reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable.", nil)
                return
            }
            
            let dateStr = self.getDateString(dayOffset: dayOffset.intValue)
            let result = self.fetchOriginData(dateStr: dateStr, deviceAddress: deviceAddress)
            
            // 顺便分发 HalfHourData 事件
            self.emitHalfHourData(dayOffset: dayOffset.intValue)
            
            resolve(result)
        }
        #endif
    }
    
    /// 读取并分发指定日期的 HalfHourData (聚合数据)
    /// - Parameter dayOffset: 日期偏移量
    private func emitHalfHourData(dayOffset: Int) {
        #if targetEnvironment(simulator)
        return
        #else
        guard let manager = VPBleCentralManage.sharedBleManager(),
              let deviceAddress = manager.peripheralModel?.deviceAddress else { return }
        
        let dateStr = self.getDateString(dayOffset: dayOffset)
        
        // 1. 获取全天总步数
        let userStature: UInt = 170
        VPDataBaseOperation.veepooSDKGetStepData(withDate: dateStr, andTableID: deviceAddress, changeUserStature: userStature) { stepDict in
            var allStep = 0
            if let dict = stepDict as? [String: Any] {
                allStep = self.getInt(dict["Step"])
            }
            
            // 2. 获取 30分钟聚合数据 (心率、运动)
            // 使用 veepooSDKGetOriginalChangeHalfHourData 接口
            var sportList: [[String: Any]] = []
            var rateList: [[String: Any]] = []
            
            let halfHourResult = VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: dateStr, andTableID: deviceAddress)
            
            if let history = halfHourResult as? [String: [String: String]] {
                // 按时间排序
                let sortedKeys = history.keys.sorted()
                
                for time in sortedKeys {
                    guard let item = history[time] else { continue }
                    
                    // Heart Rate
                    if let hrStr = item["heartValue"], let hr = Double(hrStr), hr > 0 {
                        rateList.append([
                            "time": time,
                            "rate": Int(hr)
                        ])
                    }
                    
                    // Sport
                    if let calStr = item["calValue"], let cal = Double(calStr),
                       let stepStr = item["stepValue"], let step = Double(stepStr),
                       let disStr = item["disValue"], let dis = Double(disStr) {
                        
                        if cal > 0 && step > 0 && dis > 0 {
                            sportList.append([
                                "time": time,
                                "step": Int(step),
                                "cal": cal,
                                "dis": dis
                            ])
                        }
                    }
                }
            }
            
            // 3. 获取血糖数据 (计算平均值)
            // 使用 veepooSDKGetDeviceBloodGlucoseData 接口
            var bloodGlucoseList: [[String: Any]] = []
            let bgResult = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateStr, andTableID: deviceAddress)
            
            if let bgHistory = bgResult as? [[String: Any]] {
                for item in bgHistory {
                    if let time = item["time"] as? String,
                       let glucoses = item["bloodGlucoses"] as? [String] {
                        
                        let total = glucoses.compactMap { Double($0) }.reduce(0, +)
                        let count = Double(glucoses.count)
                        let avg = count > 0 ? total / count : 0
                        
                        if avg > 0 {
                            bloodGlucoseList.append([
                                "time": time,
                                "value": avg
                            ])
                        }
                    }
                }
            }
            
            // 4. 获取血压数据 (BP)
            // 维持原有逻辑，从 5分钟原始数据中提取 (因为 HalfHour 接口可能不含 BP 或格式不同)
            var bpList: [[String: Any]] = []
            let originList = self.fetchOriginData(dateStr: dateStr, deviceAddress: deviceAddress)
            
            for item in originList {
                guard let time = item["time"] as? String else { continue }
                
                let high = item["highBP"] as? Int ?? 0
                let low = item["lowBP"] as? Int ?? 0
                if high > 0 && low > 0 {
                    bpList.append([
                        "time": time,
                        "high": high,
                        "low": low
                    ])
                }
            }
            
            // 5. 构造最终 Payload
            let payload: [String: Any] = [
                "date": dateStr,
                "allStep": allStep,
                "sportList": sportList,
                "rateList": rateList,
                "bpList": bpList,
                "bloodGlucoseList": bloodGlucoseList
            ]
            
            // 6. 发送事件
            print("🟢 [VeepooHealthHelper] Emit VeepooOriginHalfHourData for \(dateStr)")
            self.onEvent?("VeepooOriginHalfHourData", payload)
        }
        #endif
    }

    /// 提取原始数据处理逻辑，避免闭包过大导致编译器超时
    private func fetchOriginData(dateStr: String, deviceAddress: String) -> [[String: Any]] {
        #if targetEnvironment(simulator)
        return []
        #else
        // 1. 读取基础原始数据
        var originDict: [String: [String: Any]] = [:]
        if let dict = VPDataBaseOperation.veepooSDKGetOriginalData(withDate: dateStr, andTableID: deviceAddress) as? [String: [String: Any]] {
            originDict = dict
        }
        
        // 2. 读取血氧数据
        var oxygenMap: [String: [String: Any]] = [:]
        if let oxygenArray = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
            for item in oxygenArray {
                if let time = item["Time"] as? String {
                    oxygenMap[time] = item
                }
            }
        }

        // 3. 读取血糖数据
        var bloodGlucoseMap: [String: [String: Any]] = [:]
        if let bloodGlucoseArray = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
            for item in bloodGlucoseArray {
                if let time = item["time"] as? String {
                    bloodGlucoseMap[time] = item
                }
            }
        }

        // 4. 读取血液成分数据
        var bloodComponentMap: [String: VPDailyBloodAnalysisModel] = [:]
        if let bloodComponentArray = VPDataBaseOperation.veepooSDKGetDeviceBloodAnalysisData(withDate: dateStr, andTableID: deviceAddress) as? [VPDailyBloodAnalysisModel] {
            for item in bloodComponentArray {
                bloodComponentMap[item.time] = item
            }
        }
        
        var result: [[String: Any]] = []
        
        // 4. 遍历基础数据并合并
        for (time, data) in originDict {
            var item: [String: Any] = [:]
            item["time"] = time
            item["step"] = self.getInt(data["stepValue"])
            item["rate"] = self.getInt(data["heartValue"])
            item["sport"] = self.getInt(data["sportValue"])
            item["cal"] = self.getDouble(data["calValue"])
            item["dis"] = self.getDouble(data["disValue"])
            item["highBP"] = self.getInt(data["systolic"])
            item["lowBP"] = self.getInt(data["diastolic"])
            item["temp"] = self.getDouble(data["tempValue"])
            item["pressure"] = self.getInt(data["stress"])
            
            // 预留字段
            item["calcType"] = 0
            
            // 包含 ECG/PPG 原始波形数组（如果有）
            item["ppgs"] = data["ppgs"]
            item["ecgs"] = data["ecgs"]
            
            // 合并血氧数据
            if let oxyData = oxygenMap[time] {
                // 转为数组格式以匹配 OriginData 接口
                item["oxygens"] = [self.getDouble(oxyData["OxygenValue"])]
                item["resRates"] = [self.getInt(oxyData["RespirationRate"])]
                item["isHypoxias"] = [self.getInt(oxyData["IsHypoxia"])]
                item["cardiacLoads"] = [self.getDouble(oxyData["CardiacLoad"])]
                item["hypoxiaTimes"] = [self.getInt(oxyData["HypoxiaTime"])]
                item["apneaResults"] = [self.getInt(oxyData["ApneaResult"])]
            }
            
            // 合并血糖数据
            if let bgData = bloodGlucoseMap[time] {
                item["bloodGlucoses"] = bgData["bloodGlucoses"]
                item["bloodGlucoseLevels"] = bgData["bloodGlucoseLevels"]
            }
            
            // 合并血液成分数据
            if let bcData = bloodComponentMap[time] {
                let uricAcid = Double(bcData.uricAcids.first ?? "0") ?? 0
                let totalCholesterol = Double(bcData.totalCholesterols.first ?? "0") ?? 0
                let triglyceride = Double(bcData.triglycerides.first ?? "0") ?? 0
                let highDensityLipoprotein = Double(bcData.highDensityLipoproteins.first ?? "0") ?? 0
                let lowDensityLipoprotein = Double(bcData.lowDensityLipoproteins.first ?? "0") ?? 0
                
                item["bloodComponent"] = [
                    "uric_acid": uricAcid,
                    "total_cholesterol": totalCholesterol,
                    "triglyceride": triglyceride,
                    "high_density_lipoprotein": highDensityLipoprotein,
                    "low_density_lipoprotein": lowDensityLipoprotein
                ]
            }
            
            result.append(item)
        }
        
        // 按时间顺序排序 (00:00 -> 23:55)
        result.sort { ($0["time"] as? String ?? "") < ($1["time"] as? String ?? "") }
        
        return result
        #endif
    }
    
    /// 读取睡眠数据
    /// 包含深睡、浅睡、苏醒时间段及睡眠质量评分。
    /// - Parameter dayOffset: 日期偏移量
    func readSleepData(_ dayOffset: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve([])
        return
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let deviceAddress = manager.peripheralModel?.deviceAddress else {
                reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable.", nil)
                return
            }
            
            let dateStr = self.getDateString(dayOffset: dayOffset.intValue)
            
            var result: [[String: Any]] = []
            
            // 根据设备支持的睡眠类型（精准睡眠 vs 普通睡眠）获取数据
            if manager.peripheralModel.sleepType > 0 {
              if let items = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: dateStr, andTableID: deviceAddress) {
                    result = items.map { self.formatAccurateSleep($0) }
                }
            } else {
                if let items = VPDataBaseOperation.veepooSDKGetSleepData(withDate: dateStr, andTableID: deviceAddress) as? [[String: Any]] {
                    result = self.formatOrdinarySleep(items)
                }
            }
            
            resolve(result)
        }
        #endif
    }
    
    // MARK: - Format Helpers
    #if !targetEnvironment(simulator)
    /// 格式化精准睡眠数据
    private func formatAccurateSleep(_ model: VPAccurateSleepModel) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        // 日期处理 (取起床日期的前10位)
        dict["date"] = String(model.wakeTime.prefix(10))
        dict["sleepDown"] = model.sleepTime.count > 16 ? model.sleepTime : (model.sleepTime + ":00")
        dict["sleepUp"] = model.wakeTime.count > 16 ? model.wakeTime : (model.wakeTime + ":00")
        dict["sleepLine"] = model.sleepLine
        
        dict["allSleepTime"] = Double(model.sleepDuration) ?? 0
        dict["deepSleepTime"] = Double(model.deepDuration) ?? 0
        dict["lowSleepTime"] = Double(model.lightDuration) ?? 0
        dict["sleepQulity"] = Double(model.sleepQuality) ?? 0
        dict["wakeCount"] = Double(model.insomniaTimes) ?? 0
        
        dict["cali_flag"] = 0
        dict["insomniaDuration"] = 0
        dict["otherDuration"] = 0
        
        return dict
    }
    #endif
    /// 格式化普通睡眠数据  
    private func formatOrdinarySleep(_ items: [[String: Any]]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        
        for item in items {
            let sleepTime = item["SLEEP_TIME"] as? String ?? ""
            let wakeTime = item["WAKE_TIME"] as? String ?? ""
            let line = item["SLE_LINE"] as? String ?? ""
            
            let deepHourStr = item["DEEP_HOUR"] as? String ?? "0"
            let lightHourStr = item["LIGHT_HOUR"] as? String ?? "0"
            let wakeUpTimeStr = item["WakeUpTime"] as? String ?? "0"
            let sleHourStr = item["SLE_HOUR"] as? String ?? "0"
            let sleMinuteStr = item["SLE_MINUTE"] as? String ?? "0"
            
            let allSleepTime = (Double(sleHourStr) ?? 0) * 60 + (Double(sleMinuteStr) ?? 0)
            let deepSleepTime = (Double(deepHourStr) ?? 0) * 60
            let lowSleepTime = (Double(lightHourStr) ?? 0) * 60
            
            var dict: [String: Any] = [:]
            dict["date"] = String(wakeTime.prefix(10))
            dict["sleepDown"] = sleepTime
            dict["sleepUp"] = wakeTime
            dict["sleepLine"] = line
            
            dict["allSleepTime"] = allSleepTime
            dict["deepSleepTime"] = deepSleepTime
            dict["lowSleepTime"] = lowSleepTime
            dict["wakeCount"] = Double(wakeUpTimeStr) ?? 0
            
            // 尝试获取睡眠质量
            if let level = item["SLEEP_LEVEL"] {
                dict["sleepQulity"] = self.getInt(level)
            } else {
                dict["sleepQulity"] = 0
            }
            
            dict["cali_flag"] = 0
            dict["insomniaDuration"] = 0
            dict["otherDuration"] = 0
            
            result.append(dict)
        }
        
        return result
    }
    
    /// 读取运动计步数据（全天汇总）
    /// 包含当天的总步数、距离、卡路里。
    func readSportStep(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        resolve([
            "step": 5000,
            "dis": 3500,
            "kcal": 200
        ])
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let deviceAddress = manager.peripheralModel?.deviceAddress else {
                reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable.", nil)
                return
            }
            
            let dateStr = self.getDateString(dayOffset: 0)
            let userStature: UInt = 170 // 默认身高，用于计算距离（如果 SDK 内部未缓存）
            
            VPDataBaseOperation.veepooSDKGetStepData(withDate: dateStr, andTableID: deviceAddress, changeUserStature: userStature) { stepDict in
                if let dict = stepDict as? [String: Any] {
                    var result: [String: Any] = [:]
                    
                    let step = self.getInt(dict["Step"])
                    let disKm = self.getDouble(dict["Dis"])
                    let cal = self.getDouble(dict["Cal"])
                    
                    result["step"] = step
                    result["dis"] = disKm * 1000 // km to m (前端通常使用米)
                    result["kcal"] = cal
                    
                    resolve(result)
                } else {
                    // 无数据时返回 0
                    resolve([
                        "step": 0,
                        "dis": 0,
                        "kcal": 0
                    ])
                }
            }
        }
        #endif
    }
    
    /// 读取设备所有数据（同步）
    /// 触发 SDK 读取设备中存储的所有未同步数据（睡眠、运动、健康等）。
    /// 这是一个耗时操作，会通过事件回调进度。
    func readDeviceAllData(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.onEvent?("VeepooReadOriginProgress", ["progress": 0.5, "finished": false])
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.onEvent?("VeepooReadOriginProgress", ["progress": 1.0, "finished": true])
                self.onEvent?("VeepooReadOriginComplete", [:])
                resolve(true)
            }
        }
        #else
        DispatchQueue.main.async {
            guard let manager = VPBleCentralManage.sharedBleManager(),
                  let _ = manager.peripheralModel?.deviceAddress else {
                print("🔴 [VeepooHealthHelper] readDeviceAllData: No device connected")
                reject("NO_DEVICE_CONNECTED", "No device connected or address unavailable.", nil)
                return
            }
            
            print("🔵 [VeepooHealthHelper] Start reading all device data...")
            
            // 调用 SDK 全量读取接口
            manager.peripheralManage.veepooSdkStartReadDeviceAllData { readState, totalDay, currentReadDayNumber, readCurrentDayProgress in
                print("🔵 [VeepooHealthHelper] readDeviceAllData state: \(readState.rawValue), total: \(totalDay), current: \(currentReadDayNumber), progress: \(readCurrentDayProgress)")
                
                // 发送进度事件
                // 计算总进度 (0.0 - 1.0)
                // 注意：currentReadDayNumber 可能是 UInt 类型，直接 -1 可能会导致下溢崩溃 (如果为0)
                // 且需要确认 SDK 是 0-based 还是 1-based 索引。
                // 假设是 1-based，则第1天对应 current=1。如果是 0-based，则第1天对应 current=0。
                // 这里先转 Double 避免 crash，并做兼容处理。
                var overallProgress: Double = 0.0
                if totalDay > 0 {
                    // 先转为 Double 避免整型溢出
                    let currentDay = Double(currentReadDayNumber)
                    let progressInDay = Double(readCurrentDayProgress) / 100.0
                    
                    // 如果 currentDay 为 0，通常是初始状态或 0-based 的第一天
                    // 我们采用 (currentDay - 1 + progress) / total 的逻辑 (1-based)
                    // 但通过 max(0) 保护避免负数
                    overallProgress = (currentDay - 1.0 + progressInDay) / Double(totalDay)
                }
                overallProgress = min(max(overallProgress, 0.0), 1.0)
                
                self.onEvent?("VeepooReadOriginProgress", [
                    "progress": overallProgress,
                    "currentDay": currentReadDayNumber,
                    "totalDay": totalDay,
                    "finished": readState == .complete
                ])
                
                if readState == .complete {
                    print("🟢 [VeepooHealthHelper] readDeviceAllData complete. Total days: \(totalDay)")
                    self.onEvent?("VeepooReadOriginComplete", ["success": true])
                    
                    // 读取并分发所有已同步天数的数据
                    // totalDay 表示设备中存储并已读取的天数
                    let days = max(totalDay, 1) 
                    for i in 0..<days {
                        // dayOffset: 0 (今天), -1 (昨天), ...
                        self.emitHalfHourData(dayOffset: -Int(i))
                    }
                    
                    resolve(true)
                } else if readState == .invalid {
                    print("🔴 [VeepooHealthHelper] readDeviceAllData failed: Invalid state")
                    reject("READ_FAILED", "Read device data failed", nil)
                }
            }
        }
        #endif
    }
    
    // MARK: - Helper Methods
    
    /// 安全转换 Int
    private func getInt(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let v = value as? String { return Int(v) ?? 0 }
        return 0
    }
    
    /// 安全转换 Double
    private func getDouble(_ value: Any?) -> Double {
        if let v = value as? Double { return v }
        if let v = value as? String { return Double(v) ?? 0.0 }
        if let v = value as? Int { return Double(v) }
        return 0.0
    }
    
    /// 获取日期字符串 (yyyy-MM-dd)
    private func getDateString(dayOffset: Int) -> String {
        let calendar = Calendar.current
        if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        return ""
    }
}
