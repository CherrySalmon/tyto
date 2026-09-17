import { roleLabel } from './roles'

// Pure helpers behind the Accounts table: search, naming, and ordering.

const ROLE_RANK = { admin: 3, creator: 2, member: 1 }

// Shown for an account that has never logged in (login fills the name from
// Google). Bracketed so these rows group together in an alphabetical sort.
export const NO_NAME = '(not logged in yet)'

export function displayName(account) {
  return account?.name || NO_NAME
}

// Sort on the label the table shows, so nameless accounts sit together.
export function compareByName(a, b) {
  return displayName(a).localeCompare(displayName(b))
}

// Highest system role an account holds; 0 when it has none.
export function roleRank(roles) {
  return (roles || []).reduce((best, role) => Math.max(best, ROLE_RANK[role] || 0), 0)
}

// Highest role first (admin, creator, member, none), then by name/email so
// the order is stable within a rank.
export function compareByRoles(a, b) {
  const byRank = roleRank(b.roles) - roleRank(a.roles)
  if (byRank !== 0) return byRank
  return compareByName(a, b)
}

// Matches name, email, and role (key or label), case-insensitively.
export function filterAccounts(accounts, query) {
  const needle = String(query ?? '').trim().toLowerCase()
  if (!needle) return accounts
  return accounts.filter((account) => haystack(account).some((field) => field.includes(needle)))
}

function haystack(account) {
  const roles = account.roles || []
  return [account.name, account.email, ...roles, ...roles.map(roleLabel)]
    .filter(Boolean)
    .map((value) => String(value).toLowerCase())
}

