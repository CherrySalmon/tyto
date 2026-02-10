import api from './tytoApi'
import { getCurrentPosition, getGeolocationErrorMessage } from './geolocation'

export async function recordAttendance(event, { onSuccess, onError }) {
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
    const status = error.response?.status
    if (status === 403) {
      const details = error.response?.data?.details || 'Attendance was rejected'
      onError(details)
    } else {
      onError('An unexpected error occurred while recording attendance.')
    }
  }
}
