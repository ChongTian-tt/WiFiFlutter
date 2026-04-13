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
import {
  AbilityAware,
  AbilityPluginBinding,
  EventChannel,
  EventSink,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodChannel,
  MethodResult,
  MethodCallHandler,
  StreamHandler,
  Log,
} from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import bundleManager from '@ohos.bundle.bundleManager';
import type { Permissions } from '@ohos.abilityAccessCtrl';
import deviceInfo from '@ohos.deviceInfo';
import geoLocationManager from '@ohos.geoLocationManager';
import { wifiManager } from '@kit.ConnectivityKit';
import * as constants from './constants';

/** WifiScanPlugin **/
export default class WifiScanPlugin implements FlutterPlugin, AbilityAware {
  private abilityContext: common.UIAbilityContext | null = null;
  private readonly atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  private accessTokenId: number = -1;
  private readonly scanBackend: constants.ScanBackend =
    deviceInfo.sdkApiVersion >= constants.MODERN_SCAN_API_LEVEL
      ? constants.ScanBackend.MODERN
      : constants.ScanBackend.LEGACY;
  private shouldRequestOnSetting: boolean = false;
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private pollTimerId: number | null = null;
  private pollWindowTimerId: number | null = null;
  private scanStateListener: ((state: number) => void) | null = null;
  private readonly methodCallHandler: MethodCallHandler = {
    onMethodCall: (call: MethodCall, result: MethodResult): void => {
      this.handleMethodCall(call, result);
    },
  };
  private readonly streamHandler: StreamHandler = {
    onListen: (_args: Object | null, events: EventSink): void => {
      this.handleListen(events);
    },
    onCancel: (_args: Object | null): void => {
      this.handleCancel();
    },
  };

  getUniqueClassName(): string {
    return 'WifiScanPlugin';
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityContext = binding.getAbility().context as common.UIAbilityContext;
    if (this.eventSink !== null) {
      this.registerScanStateListener();
    }
  }

  onDetachedFromAbility(): void {
    this.unregisterScanStateListener();
    this.stopPolling();
    this.abilityContext = null;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), constants.CHANNEL_NAME);
    this.channel.setMethodCallHandler(this.methodCallHandler);
    this.eventChannel = new EventChannel(binding.getBinaryMessenger(), constants.SCANNED_RESULTS_EVENT);
    this.eventChannel.setStreamHandler(this.streamHandler);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
    }

    this.unregisterScanStateListener();
    this.stopPolling();
    this.eventSink?.endOfStream();
    this.eventSink = null;
    this.channel = null;
    this.eventChannel = null;
  }

  /**
   * 处理事件通道订阅并开始推送扫描结果。
   * @param events 事件发送器。
   * @returns 无。
   */
  private handleListen(events: EventSink): void {
    Log.i(constants.TAG, `handleListen`);
    this.eventSink = events;
    this.pushScannedResults();
    if (!this.registerScanStateListener()) {
      Log.i(constants.TAG, 'handleListen scan state listener unavailable, waiting for startScan polling window');
    }
  }

  /**
   * 处理事件通道取消订阅并停止结果推送。
   * @returns 无。
   */
  private handleCancel(): void {
    Log.i(constants.TAG, `handleCancel`);
    this.unregisterScanStateListener();
    this.stopPolling();
    this.eventSink?.endOfStream();
    this.eventSink = null;
  }

  /**
   * 转发方法通道调用到异步处理逻辑。
   * @param call Flutter 方法调用对象。
   * @param result Flutter 方法返回对象。
   * @returns 无。
   */
  private handleMethodCall(call: MethodCall, result: MethodResult): void {
    void this.handleMethodCallInternal(call, result);
  }

  /**
   * 分发并处理插件支持的方法调用。
   * @param call Flutter 方法调用对象。
   * @param result Flutter 方法返回对象。
   * @returns 处理完成后的 Promise。
   */
  private async handleMethodCallInternal(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      switch (call.method) {
        case 'canStartScan':
          await this.handleCanStartScan(call, result);
          break;
        case 'startScan':
          result.success(this.startScan());
          break;
        case 'canGetScannedResults':
          await this.handleCanGetScannedResults(result);
          break;
        case 'getScannedResults':
          result.success(this.getScannedResults());
          break;
        default:
          result.notImplemented();
      }
    } catch (error) {
      Log.e(constants.TAG, `handleMethodCall ${call.method} failed: ${error.message}`);
      result.error(call.method, error.message, null);
    }
  }

  /**
   * 检查当前环境是否允许开始扫描。
   * @param call Flutter 方法调用对象。
   * @param result Flutter 方法返回对象。
   * @returns 处理完成后的 Promise。
   */
  private async handleCanStartScan(call: MethodCall, result: MethodResult): Promise<void> {
    if (!call.hasArgument('askPermissions')) {
      result.error(constants.ERROR_INVALID_ARGS, 'askPermissions argument is null', null);
      return;
    }
    
    const backend: constants.ScanBackend = this.scanBackend;
    const askPermissions: boolean = this.getBooleanArgument(
      call,
      'askPermissions',
      true,
    );
    const permissionCode: number | null = await this.resolvePermissionCode(
      backend,
      askPermissions,
      constants.CAN_START_SCAN_YES,
      constants.CAN_START_SCAN_NO_LOC_PERM_REQUIRED,
      constants.CAN_START_SCAN_NO_LOC_PERM_DENIED,
      constants.CAN_START_SCAN_NO_LOC_PERM_UPGRADE_ACCURACY,
      result,
    );

    if (permissionCode === null) {
      return;
    }

    if (permissionCode !== constants.CAN_START_SCAN_YES) {
      result.success(permissionCode);
      return;
    }

    if (this.requiresLocationServiceEnabled(backend) && !this.isLocationEnabled()) {
      result.success(constants.CAN_START_SCAN_NO_LOC_DISABLED);
      return;
    }

    if (this.requiresWifiEnabledForStartScan(backend) && !this.isWifiActive()) {
      Log.i(constants.TAG, `handleCanStartScan wifi inactive on modern backend`);
      result.success(constants.CAN_START_SCAN_NOT_SUPPORTED);
      return;
    }

    if (!await this.hasScanPermission()) {
      Log.i(constants.TAG, 'handleCanStartScan missing scan permission');
      result.success(constants.CAN_START_SCAN_NOT_SUPPORTED);
      return;
    }

    result.success(constants.CAN_START_SCAN_YES);
  }

  /**
   * 发起一次平台侧 Wi-Fi 扫描。
   * @returns 是否成功触发扫描。
   */
  private startScan(): boolean {
    try {
      if (!this.isWifiActive()) {
        Log.i(constants.TAG, 'startScan skipped because Wi-Fi is inactive');
        return false;
      }

      this.startPlatformScan();
      this.startPollingWindow();
      Log.i(constants.TAG, `startScan success `);
      return true;
    } catch (error) {
      Log.i(constants.TAG, `startScan failed :${error.message}`);
      return false;
    }
  }

  /**
   * 检查当前是否允许获取扫描结果。
   * ohos 的 getScanInfoList 仅需 GET_WIFI_INFO，不依赖位置权限。
   * @param result Flutter 方法返回对象。
   * @returns 处理完成后的 Promise。
   */
  private async handleCanGetScannedResults(
    result: MethodResult,
  ): Promise<void> {
    if (!await this.hasGetScannedResultsPermission()) {
      Log.i(constants.TAG, 'handleCanGetScannedResults missing get results permission');
      result.success(constants.CAN_GET_RESULTS_NOT_SUPPORTED);
      return;
    }

    result.success(constants.CAN_GET_RESULTS_YES);
  }

  /**
   * 获取当前平台缓存的 Wi-Fi 扫描结果列表。
   * @returns 扫描结果消息数组，获取失败时返回空数组。
   */
  private getScannedResults(): Array<constants.WifiAccessPointMessage> {
    try {
      const scanInfoList: Array<wifiManager.WifiScanInfo> = wifiManager.getScanInfoList();

      Log.i(constants.TAG, `getScannedResults count: ${scanInfoList.length}`);
      return scanInfoList.map((scanInfo: wifiManager.WifiScanInfo): constants.WifiAccessPointMessage => {
        return this.mapScanInfo(scanInfo);
      });
    } catch (error) {
      Log.e(constants.TAG, `getScannedResults failed: ${error.message}`);
      return [];
    }
  }

  /**
   * 向事件通道推送当前扫描结果。
   */
  private pushScannedResults(): void {
    if (this.eventSink == null) {
      return;
    }

    const scannedResults: Array<constants.WifiAccessPointMessage> = this.getScannedResults();
    Log.i(constants.TAG, `pushScannedResults scannedResults.length: ${scannedResults.length}`);

    this.eventSink.success(scannedResults);
  }

  /**
   * 将平台扫描结果转换为通道返回的数据结构。
   * @param scanInfo 平台侧扫描结果对象。
   * @returns 转换后的接入点消息对象。
   */
  private mapScanInfo(scanInfo: wifiManager.WifiScanInfo): constants.WifiAccessPointMessage {
    return {
      ssid: scanInfo.ssid,
      bssid: scanInfo.bssid,
      capabilities: scanInfo.capabilities,
      standard: null,
      level: scanInfo.rssi,
      channelWidth: scanInfo.channelWidth,
      frequency: scanInfo.frequency,
      centerFrequency0: scanInfo.centerFrequency0,
      centerFrequency1: scanInfo.centerFrequency1,
      timestamp: scanInfo.timestamp,
      isPasspoint: null,
      operatorFriendlyName: null,
      venueName: null,
      is80211mcResponder: null,
    };
  }

  /**
   * 从方法调用参数中读取布尔值。
   * @param call Flutter 方法调用对象。
   * @param key 目标参数名称。
   * @param fallback 参数缺失时使用的默认值。
   * @returns 解析得到的布尔值。
   */
  private getBooleanArgument(
    call: MethodCall,
    key: string,
    fallback: boolean,
  ): boolean {
    if (!call.hasArgument(key)) {
      return fallback;
    }

    const args: constants.ScanRequestArguments = call.args as constants.ScanRequestArguments;
    if (key === 'askPermissions' && args.askPermissions !== undefined) {
      return args.askPermissions;
    }

    return fallback;
  }

  /**
   * 根据权限状态和请求结果转换为插件定义的返回码。
   * @param backend 当前扫描后端类型。
   * @param askPermissions 是否允许主动发起权限申请。
   * @param successCode 权限满足时返回的状态码。
   * @param requiredCode 缺少权限且未申请时返回的状态码。
   * @param deniedCode 权限申请被拒绝时返回的状态码。
   * @param upgradeCode 权限需要升级精度时返回的状态码。
   * @param result Flutter 方法返回对象。
   * @returns 权限状态码，无法继续时返回 null。
   */
  private async resolvePermissionCode(
    backend: constants.ScanBackend,
    askPermissions: boolean,
    successCode: number,
    requiredCode: number,
    deniedCode: number,
    upgradeCode: number,
    result: MethodResult,
  ): Promise<number | null> {
    if (!this.requiresLocationPermission(backend)) {
      return successCode;
    }

    const permissionStatus: constants.LocationPermissionStatus =
      await this.getLocationPermissionStatus();
    if (permissionStatus === constants.LocationPermissionStatus.GRANTED) {
      return successCode;
    }

    if (!askPermissions) {
      return permissionStatus === constants.LocationPermissionStatus.UPGRADE
        ? upgradeCode
        : requiredCode;
    }

    const requestStatus: constants.PermissionRequestStatus =
      await this.requestLocationPermissions();
    switch (requestStatus) {
      case constants.PermissionRequestStatus.GRANTED:
        return successCode;
      case constants.PermissionRequestStatus.UPGRADE:
        return upgradeCode;
      case constants.PermissionRequestStatus.DENIED:
        return deniedCode;
      case constants.PermissionRequestStatus.ERROR_NO_ABILITY:
        result.error(
          constants.ERROR_NULL_ABILITY,
          'Cannot ask for location permission.',
          'Looks like called without an attached UIAbility.',
        );
        return null;
      default:
        return requiredCode;
    }
  }

  /**
   * 查询当前定位权限的授予状态。
   * @returns 定位权限状态枚举值。
   */
  private async getLocationPermissionStatus(): Promise<constants.LocationPermissionStatus> {
    const hasLocationPermission: boolean = await this.hasPermission(
      constants.PERMISSION_LOCATION,
    );
    const hasApproximatePermission: boolean = await this.hasPermission(
      constants.PERMISSION_APPROXIMATELY_LOCATION,
    );
    if (hasLocationPermission && hasApproximatePermission) {
      return constants.LocationPermissionStatus.GRANTED;
    }
    if (hasLocationPermission || hasApproximatePermission) {
      return constants.LocationPermissionStatus.UPGRADE;
    }
    return constants.LocationPermissionStatus.REQUIRED;
  }

  /**
   * 向用户请求定位相关权限。
   * @returns 权限申请结果状态。
   */
  private async requestLocationPermissions(): Promise<constants.PermissionRequestStatus> {
    if (this.abilityContext == null) {
      return constants.PermissionRequestStatus.ERROR_NO_ABILITY;
    }

    try {
      if (this.shouldRequestOnSetting) {
        await this.atManager.requestPermissionOnSetting(
          this.abilityContext,
          constants.LOCATION_PERMISSIONS,
        );
      } else {
        await this.atManager.requestPermissionsFromUser(
          this.abilityContext,
          constants.LOCATION_PERMISSIONS,
        );
      }
    } catch (error) {
      this.shouldRequestOnSetting = true;
      return constants.PermissionRequestStatus.DENIED;
    }

    const permissionStatus: constants.LocationPermissionStatus =
      await this.getLocationPermissionStatus();
    switch (permissionStatus) {
      case constants.LocationPermissionStatus.GRANTED:
        this.shouldRequestOnSetting = false;
        return constants.PermissionRequestStatus.GRANTED;
      case constants.LocationPermissionStatus.UPGRADE:
        this.shouldRequestOnSetting = true;
        return constants.PermissionRequestStatus.UPGRADE;
      default:
        this.shouldRequestOnSetting = true;
        return constants.PermissionRequestStatus.DENIED;
    }
  }

  /**
   * 检查指定权限当前是否已被授予。
   * @param permission 待检查的权限名称。
   * @returns 是否已授予该权限。
   */
  private async hasPermission(permission: Permissions): Promise<boolean> {
    try {
      const grantStatus: abilityAccessCtrl.GrantStatus =
        await this.atManager.checkAccessToken(await this.getAccessTokenId(), permission);
      Log.i(constants.TAG, `permission: ${permission}, grantStatus: ${grantStatus}`);
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      return false;
    }
  }

  /**
   * 检查当前后端执行扫描所需的平台权限是否已授予。
   * @returns 是否具备扫描权限。
   */
  private async hasScanPermission(): Promise<boolean> {
    return this.hasPermission(constants.PERMISSION_SET_WIFI_INFO);
  }

  /**
   * 检查读取扫描结果所需的平台权限是否已授予。
   * @returns 是否具备读取扫描结果权限。
   */
  private async hasGetScannedResultsPermission(): Promise<boolean> {
    return this.hasPermission(constants.PERMISSION_GET_WIFI_INFO);
  }

  /**
   * 获取当前应用的访问令牌 ID，并在首次读取后缓存。
   * @returns 应用访问令牌 ID。
   */
  private async getAccessTokenId(): Promise<number> {
    if (this.accessTokenId >= 0) {
      return this.accessTokenId;
    }

    const bundleInfo: bundleManager.BundleInfo =
      await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION,
      );
    this.accessTokenId = bundleInfo.appInfo.accessTokenId;
    return this.accessTokenId;
  }

  /**
   * 判断系统定位服务当前是否开启。
   * @returns 定位服务是否可用。
   */
  private isLocationEnabled(): boolean {
    try {
      return geoLocationManager.isLocationEnabled();
    } catch (error) {
      return false;
    }
  }

  /**
   * 在事件监听不可用时，开启一次短时轮询窗口等待扫描结果刷新。
   * @returns 无。
   */
  private startPollingWindow(): void {
    if (this.eventSink == null) {
      return;
    }

    if (this.scanStateListener !== null) {
      return;
    }

    this.startPolling();
    if (this.pollWindowTimerId !== null) {
      clearTimeout(this.pollWindowTimerId);
    }

    this.pollWindowTimerId = setTimeout((): void => {
      Log.i(constants.TAG, 'startPollingWindow reached timeout, stopping polling');
      this.stopPolling();
    }, constants.SCAN_RESULTS_POLL_WINDOW_MS) as number;
  }

  /**
   * 启动扫描结果轮询任务。
   * @returns 无。
   */
  private startPolling(): void {
    Log.i(constants.TAG, `startPolling this.pollTimerId: ${this.pollTimerId}`);
    if (this.pollTimerId !== null) {
      return;
    }

    this.pollTimerId = setInterval((): void => {
      this.pushScannedResults();
    }, constants.SCAN_RESULTS_POLL_INTERVAL_MS) as number;
  }

  /**
   * 停止扫描结果轮询任务。
   * @returns 无。
   */
  private stopPolling(): void {
    Log.i(constants.TAG, `stopPolling this.pollTimerId: ${this.pollTimerId}`);
    if (this.pollWindowTimerId !== null) {
      clearTimeout(this.pollWindowTimerId);
      this.pollWindowTimerId = null;
    }

    if (this.pollTimerId === null) {
      return;
    }

    clearInterval(this.pollTimerId);
    this.pollTimerId = null;
  }

  /**
   * 注册系统扫描状态事件，用于在扫描完成时主动推送结果。
   * @returns 是否注册成功。
   */
  private registerScanStateListener(): boolean {
    if (this.scanStateListener !== null) {
      return true;
    }

    this.scanStateListener = (state: number): void => {
      Log.i(constants.TAG, `wifiScanStateChange state: ${state}`);
      this.pushScannedResults();
    };

    try {
      wifiManager.on('wifiScanStateChange', this.scanStateListener);
      Log.i(constants.TAG, 'registerScanStateListener success');
      return true;
    } catch (error) {
      Log.e(constants.TAG, `registerScanStateListener failed: ${error.message}`);
      this.scanStateListener = null;
      return false;
    }
  }

  /**
   * 注销系统扫描状态事件监听。
   * @returns 无。
   */
  private unregisterScanStateListener(): void {
    if (this.scanStateListener === null) {
      return;
    }

    try {
      wifiManager.off('wifiScanStateChange', this.scanStateListener);
    } catch (error) {
      Log.e(constants.TAG, `unregisterScanStateListener failed: ${error.message}`);
    } finally {
      this.scanStateListener = null;
    }
  }

  /**
   * 根据当前后端类型调用对应的平台扫描接口。
   * @returns 无。
   */
  private startPlatformScan(): void {
    try {
      if (this.scanBackend === constants.ScanBackend.MODERN) {
        wifiManager.startScan();
      } else {
        wifiManager.scan();
      }
    } catch (error) {
      throw new Error(`Wi-Fi scan failed: ${error.message}`);
    }
  }

  /**
   * 判断当前后端是否要求定位权限。
   * @param backend 扫描后端类型。
   * @returns 是否依赖定位权限。
   */
  private requiresLocationPermission(backend: constants.ScanBackend): boolean {
    return backend === constants.ScanBackend.LEGACY;
  }

  /**
   * 判断当前后端是否要求定位服务开启。
   * @param backend 扫描后端类型。
   * @returns 是否依赖定位服务状态。
   */
  private requiresLocationServiceEnabled(backend: constants.ScanBackend): boolean {
    return backend === constants.ScanBackend.LEGACY;
  }

  /**
   * 判断开始扫描前是否要求 Wi-Fi 处于启用状态。
   * @param backend 扫描后端类型。
   * @returns 是否需要先启用 Wi-Fi。
   */
  private requiresWifiEnabledForStartScan(backend: constants.ScanBackend): boolean {
    return backend === constants.ScanBackend.MODERN;
  }

  /**
   * 判断当前设备的 Wi-Fi 是否处于激活状态。
   * @returns Wi-Fi 是否已启用。
   */
  private isWifiActive(): boolean {
    try {
      return wifiManager.isWifiActive();
    } catch (error) {
      return false;
    }
  }
}
