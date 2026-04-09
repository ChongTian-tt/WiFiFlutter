/*
 * Copyright (C) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the 'License');
 
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import type { Permissions } from '@ohos.abilityAccessCtrl';

export const TAG = 'WifiScanPlugin';
export const CHANNEL_NAME = 'wifi_scan';
export const SCANNED_RESULTS_EVENT = 'wifi_scan/onScannedResultsAvailable';
export const MODERN_SCAN_API_LEVEL = 21;

export const ERROR_INVALID_ARGS = 'InvalidArgs';
export const ERROR_NULL_ABILITY = 'NullAbility';

export const PERMISSION_GET_WIFI_INFO: Permissions = 'ohos.permission.GET_WIFI_INFO';
export const PERMISSION_SET_WIFI_INFO: Permissions = 'ohos.permission.SET_WIFI_INFO';
export const PERMISSION_LOCATION: Permissions = 'ohos.permission.LOCATION';
export const PERMISSION_APPROXIMATELY_LOCATION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
export const LOCATION_PERMISSIONS: Array<Permissions> = [
  PERMISSION_LOCATION,
  PERMISSION_APPROXIMATELY_LOCATION,
];

export const SCAN_RESULTS_POLL_INTERVAL_MS = 3000;
export const WIFI_SCAN_STATE_FAILED = 0;
export const WIFI_SCAN_STATE_SUCCESS = 1;

// 不支持扫描时返回的状态码。
export const CAN_START_SCAN_NOT_SUPPORTED = 0;
// 权限满足时返回的状态码。
export const CAN_START_SCAN_YES = 1;
// 缺少权限且未申请时返回的状态码。
export const CAN_START_SCAN_NO_LOC_PERM_REQUIRED = 2;
// 权限申请被拒绝时返回的状态码。
export const CAN_START_SCAN_NO_LOC_PERM_DENIED = 3;
// 权限需要升级精度时返回的状态码。
export const CAN_START_SCAN_NO_LOC_PERM_UPGRADE_ACCURACY = 4;
// 权限满足但位置服务被禁用时返回的状态码。
export const CAN_START_SCAN_NO_LOC_DISABLED = 5;

export const CAN_GET_RESULTS_NOT_SUPPORTED = 0;
export const CAN_GET_RESULTS_YES = 1;

export enum LocationPermissionStatus {
  GRANTED,
  REQUIRED,
  UPGRADE,
}

export enum PermissionRequestStatus {
  GRANTED,
  DENIED,
  UPGRADE,
  ERROR_NO_ABILITY,
}

export enum ScanBackend {
  LEGACY,
  MODERN,
}

export interface ScanRequestArguments {
  askPermissions?: boolean;
}

export interface WifiAccessPointMessage {
  ssid: string;
  bssid: string;
  capabilities: string;
  frequency: number;
  level: number;
  timestamp: number | null;
  standard: number | null;
  centerFrequency0: number | null;
  centerFrequency1: number | null;
  channelWidth: number | null;
  isPasspoint: boolean | null;
  operatorFriendlyName: string | null;
  venueName: string | null;
  is80211mcResponder: boolean | null;
}