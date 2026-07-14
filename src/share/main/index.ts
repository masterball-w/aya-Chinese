import { app, session } from 'electron'
import isMac from 'licia/isMac'
import * as theme from './lib/theme'
import * as language from './lib/language'
import * as ipc from './lib/ipc'
import * as updater from './lib/updater'
import pkg from '../../../package.json'
import { setupTitlebar } from 'custom-electron-titlebar/main'
import isWindows from 'licia/isWindows'
import log from '../common/log'

const logger = log('main')

// 防止未捕获异常弹出 Electron 错误对话框，改为记录日志
process.on('uncaughtException', (err) => {
  logger.error('uncaughtException', err)
})

process.on('unhandledRejection', (err) => {
  logger.error('unhandledRejection', err)
})

if (!app.requestSingleInstanceLock()) {
  app.quit()
  process.exit(0)
}

if (!isMac) {
  app.disableHardwareAcceleration()
}

app.setName(pkg.productName)

app.on('ready', () => {
  if (!isMac && !isWindows) {
    session.defaultSession.setSpellCheckerLanguages([])
  }
  setupTitlebar()
  language.init()
  theme.init()
  ipc.init()
  updater.init()
})
