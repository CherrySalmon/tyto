import api from './tyto-api'
import { getCurrentPosition, getGeolocationErrorMessage } from './geolocation'

export async function recordAttendance(event, { onSuccess, onError, onDuplicate }) {
  let position
  try {
    position = await getCurrentPosition()
  } catch (geoError) {
    onError(getGeolocationErrorMessage(geoError))
    return
  }

  const { latitude, longitude } = position.coords

  try {
    await api.post(`/course/${event.course_id}/attendance`, {
      event_id: event.id,
      name: event.name,
      latitude,
      longitude,
    })
    onSuccess(event.id)
  } catch (error) {
    if (error.response?.status === 403) {
      const details = error.response?.data?.details || 'Attendance was rejected'
      onError(details)
    } else {
      onDuplicate(event.id)
    }
  }
}
