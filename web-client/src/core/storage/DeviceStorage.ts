/**
 * 设备存储管理
 * 用于支持多设备同时登录，为每个设备生成唯一标识
 */

export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  lastActive: number;
}

const STORAGE_KEY = 'device_info';

/**
 * 生成或获取当前设备ID
 */
export function getDeviceId(): string {
  const deviceInfo = getDeviceInfo();
  if (deviceInfo?.deviceId) {
    return deviceInfo.deviceId;
  }

  // 生成新的设备ID
  const newDeviceId = generateDeviceId();
  const newDeviceInfo: DeviceInfo = {
    deviceId: newDeviceId,
    deviceName: getDeviceName(),
    lastActive: Date.now(),
  };
  setDeviceInfo(newDeviceInfo);
  return newDeviceId;
}

/**
 * 获取设备信息
 */
export function getDeviceInfo(): DeviceInfo | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      return JSON.parse(stored);
    }
  } catch {
    return null;
  }
  return null;
}

/**
 * 设置设备信息
 */
export function setDeviceInfo(deviceInfo: DeviceInfo): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(deviceInfo));
  } catch (error) {
    console.warn('Failed to store device info:', error);
  }
}

/**
 * 更新设备最后活跃时间
 */
export function updateDeviceActivity(): void {
  const deviceInfo = getDeviceInfo();
  if (deviceInfo) {
    deviceInfo.lastActive = Date.now();
    setDeviceInfo(deviceInfo);
  }
}

/**
 * 生成唯一设备ID
 */
function generateDeviceId(): string {
  // 使用多种信息组合生成唯一ID
  const randomPart = Math.random().toString(36).substring(2, 15);
  const timePart = Date.now().toString(36);
  return `${randomPart}-${timePart}`;
}

/**
 * 获取设备名称
 */
function getDeviceName(): string {
  const userAgent = navigator.userAgent;
  let deviceName = 'Unknown Device';

  if (/Mobile|Android|iPhone|iPad/i.test(userAgent)) {
    deviceName = 'Mobile Device';
  } else if (/Windows/i.test(userAgent)) {
    deviceName = 'Windows PC';
  } else if (/Mac/i.test(userAgent)) {
    deviceName = 'Mac PC';
  } else if (/Linux/i.test(userAgent)) {
    deviceName = 'Linux PC';
  }

  // 添加浏览器信息
  if (/Chrome/i.test(userAgent)) {
    deviceName += ' (Chrome)';
  } else if (/Firefox/i.test(userAgent)) {
    deviceName += ' (Firefox)';
  } else if (/Safari/i.test(userAgent)) {
    deviceName += ' (Safari)';
  } else if (/Edge/i.test(userAgent)) {
    deviceName += ' (Edge)';
  }

  return deviceName;
}

/**
 * 清除设备信息
 */
export function clearDeviceInfo(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch (error) {
    console.warn('Failed to clear device info:', error);
  }
}
