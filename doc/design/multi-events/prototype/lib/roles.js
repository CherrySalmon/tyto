const SYSTEM_ROLES = {
  admin: { label: 'Admin', description: 'manage accounts' },
  creator: { label: 'Creator', description: 'create courses' },
  member: { label: 'Member', description: 'mark attendance' }
}

export const roleOptions = Object.entries(SYSTEM_ROLES).map(
  ([value, { label }]) => ({ label, value })
)

export function describeRoles(roles) {
  return roles
    .map((role) => SYSTEM_ROLES[role]?.description)
    .filter(Boolean)
    .join(', ')
}
