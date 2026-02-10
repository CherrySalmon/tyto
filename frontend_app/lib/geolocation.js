export function getCurrentPosition() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('Geolocation is not supported by this browser.'))
      return
    }

    navigator.geolocation.getCurrentPosition(resolve, reject)
  })
}

export function getGeolocationErrorMessage(error) {
  if (!error.code) {
    return error.message || 'An unknown error occurred.'
  }

  switch (error.code) {
    case error.PERMISSION_DENIED:
      return 'User denied the request for Geolocation.'
    case error.POSITION_UNAVAILABLE:
      return 'Location information is unavailable.'
    case error.TIMEOUT:
      return 'The request to get user location timed out.'
    default:
      return 'An unknown error occurred.'
  }
}
