import { useMemo } from 'react'
import Thumb from './Thumb'
import { AlbumSortBy, IAlbum, IScanStats } from './types'
import Style from './Album.module.scss'

interface IProps {
  deviceId: string
  albums: IAlbum[]
  sortBy: AlbumSortBy
  onSortChange: (sortBy: AlbumSortBy) => void
  onOpen: (album: IAlbum) => void
  onScan: () => void
  onSettings: () => void
  scanning: boolean
  stats: IScanStats | null
  clipboardCount?: number
}

function formatTime(mtime: number | null | undefined): string {
  if (!mtime) {
    return '—'
  }
  const date = new Date(mtime)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(
    date.getDate()
  ).padStart(2, '0')}`
}

export default function AlbumList(props: IProps) {
  const {
    deviceId,
    albums,
    sortBy,
    onSortChange,
    onOpen,
    onScan,
    onSettings,
    scanning,
    stats,
    clipboardCount,
  } = props

  const sorted = useMemo(() => {
    const arr = [...albums]
    arr.sort((a, b) => {
      if (sortBy === 'count') {
        return b.count - a.count
      }
      const am = a.latest ? a.latest.mtime : 0
      const bm = b.latest ? b.latest.mtime : 0
      return bm - am
    })
    return arr
  }, [albums, sortBy])

  return (
    <div className={Style.container}>
      <div className={Style.viewBar}>
        <button
          className={`${Style.btn} ${Style.btnPrimary}`}
          onClick={onScan}
          disabled={scanning}
        >
          {scanning ? '扫描中…' : '扫描 / 增量刷新'}
        </button>
        <div className={Style.viewMeta}>
          {albums.length > 0 ? `发现 ${albums.length} 个相册` : ''}
          {stats && ` · 读取 ${stats.readDirs} / 复用 ${stats.reusedDirs} 个目录`}
        </div>
        <div className={Style.viewControls}>
          <select
            className={Style.select}
            value={sortBy}
            onChange={(e) => onSortChange(e.target.value as AlbumSortBy)}
          >
            <option value="time">按时间排序</option>
            <option value="count">按数量排序</option>
          </select>
          <button className={Style.btn} onClick={onSettings}>
            设置
          </button>
        </div>
      </div>
      {scanning && (
        <div className={Style.scanProgress}>正在扫描存储,首次扫描可能需要几分钟…</div>
      )}
      {!scanning && !!clipboardCount && clipboardCount > 0 && (
        <div className={Style.scanProgress}>
          剪贴板中有 {clipboardCount} 张图片,进入目标相册后按 Ctrl+V 或点击「粘贴」即可复制到该相册
        </div>
      )}
      <div className={Style.albumScroll}>
        {sorted.length === 0 && !scanning && (
          <div className={Style.empty}>
            没有发现相册。可尝试降低阈值(设置中修改)或点击「扫描」。
          </div>
        )}
        <div className={Style.albumGrid}>
          {sorted.map((album) => (
            <div
              key={album.path}
              className={Style.albumCard}
              onClick={() => onOpen(album)}
            >
              <div className={Style.cardCover}>
                {album.latest ? (
                  <Thumb
                    deviceId={deviceId}
                    path={album.latest.path}
                    mtime={album.latest.mtime}
                    square
                  />
                ) : (
                  <div className={Style.thumbPlaceholder}>✕</div>
                )}
              </div>
              <div className={Style.cardInfo}>
                <div className={Style.cardName} title={album.path}>
                  {album.name}
                </div>
                <div className={Style.cardPath} title={album.path}>
                  {album.path}
                </div>
                <div className={Style.cardMeta}>
                  {album.count} 张 · 最近 {formatTime(album.latest?.mtime)}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
