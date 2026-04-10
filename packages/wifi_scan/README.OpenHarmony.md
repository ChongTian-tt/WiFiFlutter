# wifi_scan

This project is based on [wifi_scan](https://github.com/flutternetwork/WiFiFlutter/tree/master/packages/wifi_scan) and provides Wi-Fi scanning capabilities for OpenHarmony Flutter, including triggering scans, retrieving scan results, and real-time scan result streaming.

## 1. Installation & Usage

### 1.1 Installation

Navigate to your project directory and add the dependency in `pubspec.yaml`:

#### pubspec.yaml

```yaml
dependencies:
  wifi_scan:
    git:
      url: https://gitcode.com/org/OpenHarmony-Flutter/fluttertpc_wifi_scan
      ref: master
```
Run:

```bash
flutter pub get
```

### 1.2 Usage Example

See the full example at [example](example/lib/main.dart).

The simplest usage:

```dart
import 'package:wifi_scan/wifi_scan.dart';

// Check if scanning is available
final can = await WiFiScan.instance.canStartScan(askPermissions: true);
if (can == CanStartScan.yes) {
  // Trigger a Wi-Fi scan
  final success = await WiFiScan.instance.startScan();
  // Get scan results
  final results = await WiFiScan.instance.getScannedResults();
  for (final ap in results) {
    print('SSID: ${ap.ssid}, RSSI: ${ap.level}');
  }
}

// Listen for real-time scan result updates
WiFiScan.instance.onScannedResultsAvailable.listen((results) {
  print('Found ${results.length} access points');
});
```

## 2. Constraints
1. Flutter: 3.7.12-ohos-1.0.6; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。
2. Flutter: 3.22.1-ohos-1.0.3; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。
3. Flutter: oh-3.27.4-dev; SDK: 5.0.0(12); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。
4. Flutter: 3.35.8-ohos-0.0.1; SDK: 6.0.1(21); IDE: DevEco Studio 6.0.2.642; ROM: 6.0.0.130 SP25。

## 3. Version and Framework Mapping
|       | 3.7 | 3.22 | 3.27 | 3.35 |
|-------|:---:|:----:|:----:|:----:|
| 1.0.0 |  ✅  |  ✅   |  ✅   |  ✅   |

## 4. API

> [!TIP] "ohos Support" column: yes = supported; no = not supported; partially = partially supported.

### WiFiScan

| Name | Description | Type | Input | Output | ohos Support |
| --- | --- | --- | --- | --- | --- |
| canStartScan | Check if Wi-Fi scanning can be triggered | function | {askPermissions: bool} | Future\<CanStartScan\> | yes |
| startScan | Trigger a Wi-Fi scan | function | - | Future\<bool\> | yes |
| canGetScannedResults | Check if scanned results can be retrieved | function | {askPermissions: bool} | Future\<CanGetScannedResults\> | yes |
| getScannedResults | Get the latest scanned Wi-Fi access points | function | - | Future\<List\<WiFiAccessPoint\>\> | yes |
| onScannedResultsAvailable | Stream of real-time scan result updates | getter | - | Stream\<List\<WiFiAccessPoint\>\> | yes |

### WiFiAccessPoint Properties

| Name | Description | Type | ohos Support |
| --- | --- | --- | --- |
| ssid | Network name | String | yes |
| bssid | Access point MAC address | String | yes |
| capabilities | Authentication and encryption schemes | String | yes |
| frequency | Primary channel frequency (MHz) | int | yes |
| level | Signal strength RSSI (dBm) | int | yes |
| timestamp | Last seen timestamp (μs) | int? | yes |
| channelWidth | Channel bandwidth | WiFiChannelWidth? | yes |
| centerFrequency0 | Center frequency 0 | int? | yes |
| centerFrequency1 | Center frequency 1 | int? | yes |
| standard | Wi-Fi standard (802.11a/n/ac/ax/ad) | WiFiStandards | no |
| isPasspoint | Whether the AP is a Passpoint (Hotspot 2.0) | bool? | no |
| operatorFriendlyName | Passpoint operator name | String? | no |
| venueName | Passpoint venue name | String? | no |
| is80211mcResponder | Whether 802.11mc (WiFi RTT) ranging is supported | bool? | no |

> **Note:** The ohos `getScanInfoList` API (API 10+) only requires `ohos.permission.GET_WIFI_INFO` permission and does not depend on location permissions. Therefore, `canGetScannedResults` on ohos only returns `notSupported` or `yes`.

## 5. Known Limitations

The following WiFiAccessPoint properties are not supported on ohos and always return null: `standard` (Wi-Fi standard), `isPasspoint` (Passpoint detection), `operatorFriendlyName` (operator name), `venueName` (venue name), `is80211mcResponder` (802.11mc ranging support).

## 6. License

This project is licensed under the [MIT](LICENSE) License.
