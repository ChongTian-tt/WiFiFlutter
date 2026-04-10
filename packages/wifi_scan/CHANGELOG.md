## 1.0.0

- 完成 OpenHarmony 平台适配，基于上游 wifi_scan 0.4.1+2 版本。
- 支持 `canStartScan` 接口，检测扫描条件（权限、Wi-Fi 状态、位置服务）。
- 支持 `startScan` 接口，触发平台侧 Wi-Fi 扫描。
- 支持 `canGetScannedResults` 接口，检测获取结果条件。
- 支持 `getScannedResults` 接口，获取缓存的扫描结果列表。
- 支持 `onScannedResultsAvailable` 事件流，实时推送扫描结果更新。
- 适配 ohos 权限模型：`ohos.permission.GET_WIFI_INFO`、`ohos.permission.SET_WIFI_INFO`、`ohos.permission.LOCATION`、`ohos.permission.APPROXIMATELY_LOCATION`。
- 支持 `wifiScanStateChange` 系统事件监听，扫描完成后主动推送结果。
- 提供轮询回退机制，在事件监听不可用时通过短时轮询窗口保障结果推送。
- 适配 LEGACY / MODERN 双扫描后端，根据设备 SDK API 版本自动切换。
- WiFiAccessPoint 属性中 `standard`、`isPasspoint`、`operatorFriendlyName`、`venueName`、`is80211mcResponder` 因 ohos 平台接口限制暂不支持，返回 null。
