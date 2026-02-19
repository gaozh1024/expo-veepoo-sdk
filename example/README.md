# Expo Veepoo SDK Example

这是一个用于测试 `@gaozh1024/expo-veepoo-sdk` 的示例项目。

## 运行步骤

### 1. 安装依赖

```bash
npm install
```

### 2. 预构建原生代码

由于模块包含原生 frameworks，需要预构建：

```bash
npx expo prebuild --clean
```

### 3. iOS 额外步骤

```bash
cd ios && pod install && cd ..
```

### 4. 运行应用

```bash
# 启动开发服务器
npx expo start

# 按 'i' 运行 iOS
# 按 'a' 运行 Android
```

## 测试功能

- 设备扫描
- 设备连接/断开
- 心率测试
- 血压测试
- 血氧测试
- 体温测试
- 压力测试
- 血糖测试
- 电量读取

## 注意事项

1. 需要真机测试（蓝牙功能在模拟器上不可用）
2. iOS 需要开发构建（不支持 Expo Go）
3. Android 可以使用 Expo Go，但原生模块需要开发构建
