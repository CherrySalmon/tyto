import session from '@/lib/session'

// Only admins may manage accounts (plan Q9). Routes flagged with
// `meta.requiresAdmin` send everyone else to the home page. The nav already
// hides the link; this closes the direct-URL path.
export function adminGuard(to) {
  if (!to?.meta?.requiresAdmin) return true
  const account = session.getAccount()
  return account && account.roles.includes('admin') ? true : '/'
}
