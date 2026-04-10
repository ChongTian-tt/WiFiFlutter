# wifi_scan

本项目基于 [wifi_scan](https://github.com/flutternetwork/WiFiFlutter/tree/master/packages/wifi_scan) 开发，为 OpenHarmony Flutter 场景提供 Wi-Fi 扫描功能，支持触发扫描、获取扫描结果及实时监听扫描结果更新。

## 1. 安装与使用

### 1.1 安装方式

进入工程目录并在 `pubspec.yaml` 中添加依赖：

#### pubspec.yaml

```yaml
dependencies:
  wifi_scan:
    git:
      url: https://gitcode.com/org/OpenHarmony-Flutter/fluttertpc_wifi_scan
      ref: master
```
执行命令：

```bash
flutter pub get
```

### 1.2 使用案例

使用案例详见 [example](example/lib/main.dart)。

最简单的调用方式：

```dart
import 'package:wifi_scan/wifi_scan.dart';

// 检查是否可以开始扫描
final can = await WiFiScan.instance.canStartScan(askPermissions: true);
if (can == CanStartScan.yes) {
  // 触发 Wi-Fi 扫描
  final success = await WiFiScan.instance.startScan();
  // 获取扫描结果
  final results = await WiFiScan.instance.getScannedResults();
  for (final ap in results) {
    print('SSID: ${ap.ssid}, RSSI: ${ap.level}');
  }
}

// 监听扫描结果实时更新
WiFiScan.instance.onScannedResultsAvailable.listen((results) {
  print('发现 ${results.length} 个接入点');
});
```

## 2. 约束条件
1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。
2. Flutter: 3.22.1-ohos-1.0.3; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。
3. Flutter: oh-3.27.4-dev; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。
4. Flutter: 3.35.8-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。

## 3. 版本和框架对应关系
|       | 3.7 | 3.22 | 3.27 | 3.35 |
|-------|:---:|:----:|:----:|:----:|
| 1.0.0 |  ✅  |  ✅   |  ✅   |  ✅   |

## 4. API

> [!TIP] "ohos Support" 列：yes 表示支持；no 表示不支持；partially 表示部分支持。

### WiFiScan

| Name | Description | Type | Input | Output | ohos Support |
| --- | --- | --- | --- | --- | --- |
| canStartScan | 检查当前环境是否可以触发 Wi-Fi 扫描 | function | {askPermissions: bool} | Future\<CanStartScan\> | yes |
| startScan | 触发一次 Wi-Fi 扫描 | function | - | Future\<bool\> | yes |
| canGetScannedResults | 检查当前环境是否可以获取扫描结果 | function | {askPermissions: bool} | Future\<CanGetScannedResults\> | yes |
| getScannedResults | 获取最近一次扫描的 Wi-Fi 接入点列表 | function | - | Future\<List\<WiFiAccessPoint\>\> | yes |
| onScannedResultsAvailable | 监听扫描结果更新的实时事件流 | getter | - | Stream\<List\<WiFiAccessPoint\>\> | yes |

### WiFiAccessPoint 属性

| Name | Description | Type | ohos Support |
| --- | --- | --- | --- |
| ssid | 网络名称 | String | yes |
| bssid | 接入点 MAC 地址 | String | yes |
| capabilities | 认证与加密方案描述 | String | yes |
| frequency | 主信道频率 (MHz) | int | yes |
| level | 信号强度 RSSI (dBm) | int | yes |
| timestamp | 最后发现时间戳 (μs) | int? | yes |
| channelWidth | 信道带宽 | WiFiChannelWidth? | yes |
| centerFrequency0 | 中心频率 0 | int? | yes |
| centerFrequency1 | 中心频率 1 | int? | yes |
| standard | Wi-Fi 标准 (802.11a/n/ac/ax/ad) | WiFiStandards | no |
| isPasspoint | 是否为 Passpoint (Hotspot 2.0) 热点 | bool? | no |
| operatorFriendlyName | Passpoint 运营商名称 | String? | no |
| venueName | Passpoint 场所名称 | String? | no |
| is80211mcResponder | 是否支持 802.11mc (WiFi RTT) 测距 | bool? | no |

> **说明：** ohos 平台的 `getScanInfoList` 接口（API 10+）仅需 `ohos.permission.GET_WIFI_INFO` 权限，不依赖位置权限，因此 `canGetScannedResults` 在 ohos 上只返回 `notSupported` 或 `yes`。

## 5. 遗留问题

ohos 暂不支持以下 WiFiAccessPoint 属性：`standard`（Wi-Fi 标准）、`isPasspoint`（Passpoint 检测）、`operatorFriendlyName`（运营商名称）、`venueName`（场所名称）、`is80211mcResponder`（802.11mc 测距支持），这些属性在 ohos 平台始终返回 null。

## 6. 开源协议

本项目基于 [MIT](LICENSE) 开源。
