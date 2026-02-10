export function formatLocalDateTime(utcStr) {
  if (!utcStr) return null

  const date = new Date(utcStr)
  if (Number.isNaN(date.getTime())) {
    console.error('Invalid date value:', utcStr)
    return null
  }

  return date.getFullYear()
    + '-' + String(date.getMonth() + 1).padStart(2, '0')
    + '-' + String(date.getDate()).padStart(2, '0')
    + ' ' + String(date.getHours()).padStart(2, '0')
    + ':' + String(date.getMinutes()).padStart(2, '0')
}
