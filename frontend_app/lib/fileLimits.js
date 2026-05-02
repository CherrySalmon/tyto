// Single source of truth for upload size limits on the frontend side.
// Mirrors backend Tyto::FileStorage::MAX_SIZE_BYTES — bumping the cap means
// updating both files.
export const MAX_SIZE_BYTES = 10 * 1024 * 1024
export const MAX_SIZE_MB = MAX_SIZE_BYTES / (1024 * 1024)
