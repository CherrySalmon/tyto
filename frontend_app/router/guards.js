import session from '@/lib/session'

// Only admins may manage accounts (plan Q9). Routes flagged with
// `meta.requiresAdmin` send everyone else to the home page. The nav already
// hides the link; this closes the direct-URL path. The guard refreshes the
// session from the server first, so it decides on the roles as they are now,
// not the cookie written at login.
export async function adminGuard(to) {
  if (!to?.meta?.requiresAdmin) return true
  const account = await session.refresh()
  return account && account.roles.includes('admin') ? true : '/'
}
