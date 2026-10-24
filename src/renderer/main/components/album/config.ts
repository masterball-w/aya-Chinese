const CONFIG_PREFIX = 'aya-album-config:'

export interface IAlbumConfig {
  threshold: number
  scanRoot: string
  excludedNames: string[]
  excludeHidden: boolean
  respectNoMedia: boolean
  concurrency: number
  thumbLongSide: number
}

export const DEFAULT_CONFIG: IAlbumConfig = {
  threshold: 5,
  scanRoot: '/sdcard',
  excludedNames: ['Android'],
  excludeHidden: true,
  respectNoMedia: true,
  concurrency: 8,
  thumbLongSide: 480,
}

export function loadConfig(deviceId: string): IAlbumConfig {
  try {
    const raw = localStorage.getItem(CONFIG_PREFIX + deviceId)
    if (raw) {
      return { ...DEFAULT_CONFIG, ...JSON.parse(raw) }
    }
  } catch {
    // 配置损坏时回退默认值
  }
  return { ...DEFAULT_CONFIG }
}

export function saveConfig(deviceId: string, config: IAlbumConfig) {
  try {
    localStorage.setItem(CONFIG_PREFIX + deviceId, JSON.stringify(config))
  } catch {
    // 存储不可用时忽略
  }
}

const CACHE_PREFIX = 'aya-album-cache:'

export function loadScanCache(deviceId: string) {
  try {
    const raw = localStorage.getItem(CACHE_PREFIX + deviceId)
    if (raw) {
      return JSON.parse(raw)
    }
  } catch {
    // 缓存损坏时视为无缓存
  }
  return null
}

export function saveScanCache(deviceId: string, cache: unknown) {
  try {
    localStorage.setItem(CACHE_PREFIX + deviceId, JSON.stringify(cache))
  } catch {
    // 超出 localStorage 容量时放弃持久化,仅本次会话内生效
  }
}
