#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(VeepooBleModule, RCTEventEmitter)

// 初始化 SDK
RCT_EXTERN_METHOD(initSDK)

// 获取蓝牙状态
RCT_EXTERN_METHOD(getBluetoothStatus:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 开始扫描设备
RCT_EXTERN_METHOD(startScan)

// 停止扫描设备
RCT_EXTERN_METHOD(stopScan)

// 连接设备
RCT_EXTERN_METHOD(connectDevice:(NSString *)macAddress 
                  uuid:(NSString *)uuid
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 断开设备连接 
RCT_EXTERN_METHOD(disconnectDevice:(NSString *)macAddress)

// 验证密码
RCT_EXTERN_METHOD(verifyPassword:(NSString *)password
                  is24Hour:(BOOL)is24Hour
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 同步个人信息
RCT_EXTERN_METHOD(syncPersonInfo:(NSInteger)sex
                  height:(double)height
                  weight:(double)weight
                  age:(NSInteger)age
                  stepAim:(NSInteger)stepAim
                  sleepAim:(NSInteger)sleepAim
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 读取自动测量设置
RCT_EXTERN_METHOD(readAutoMeasureSetting:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 修改自动测量设置
RCT_EXTERN_METHOD(modifyAutoMeasureSetting:(NSDictionary *)setting
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 读取电池电量
RCT_EXTERN_METHOD(readBattery:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 获取设备版本号
RCT_EXTERN_METHOD(getDeviceVersion:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 读取原始数据
RCT_EXTERN_METHOD(readOriginData:(nonnull NSNumber *)dayOffset
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 读取睡眠数据
RCT_EXTERN_METHOD(readSleepData:(nonnull NSNumber *)dayOffset
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 读取运动步数
RCT_EXTERN_METHOD(readSportStep:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 读取设备全部日常数据
RCT_EXTERN_METHOD(readDeviceAllData:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 开始检测心率
RCT_EXTERN_METHOD(startDetectHeart:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 停止检测心率
RCT_EXTERN_METHOD(stopDetectHeart:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 开始检测血压
RCT_EXTERN_METHOD(startDetectBP:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 停止检测血压
RCT_EXTERN_METHOD(stopDetectBP:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 开始检测血氧
RCT_EXTERN_METHOD(startDetectSPO2H:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 停止检测血氧
RCT_EXTERN_METHOD(stopDetectSPO2H:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 开始检测血糖
RCT_EXTERN_METHOD(measureBloodGlucose:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 停止检测血糖
RCT_EXTERN_METHOD(cancelMeasureBloodGlucose:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 开始检测压力
RCT_EXTERN_METHOD(startDetectStress:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// 停止检测压力
RCT_EXTERN_METHOD(stopDetectStress:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

@end
