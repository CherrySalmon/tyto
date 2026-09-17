import { describe, it, expect } from 'vitest';
import { filterAccounts, compareByRoles, roleRank } from './accountsTable';

const accounts = [
  { id: 1, name: 'Soumya Ray', email: 's.ray@example.edu', roles: ['admin', 'creator'] },
  { id: 2, name: 'Lin Chen', email: 'lin.chen@example.edu', roles: ['creator', 'member'] },
  { id: 3, name: null, email: 'ali.hassan@example.edu', roles: ['member'] },
  { id: 4, name: 'Mei Tanaka', email: 'mei.tanaka@example.edu', roles: [] },
];

describe('filterAccounts', () => {
  it('returns everything for a blank query', () => {
    expect(filterAccounts(accounts, '')).toEqual(accounts);
    expect(filterAccounts(accounts, '   ')).toEqual(accounts);
  });

  it('matches name and email case-insensitively', () => {
    expect(filterAccounts(accounts, 'LIN').map((a) => a.id)).toEqual([2]);
    expect(filterAccounts(accounts, 'hassan@').map((a) => a.id)).toEqual([3]);
  });

  it('matches a role by key or label', () => {
    expect(filterAccounts(accounts, 'creator').map((a) => a.id)).toEqual([1, 2]);
    expect(filterAccounts(accounts, 'Admin').map((a) => a.id)).toEqual([1]);
  });

  it('copes with accounts that have no name yet', () => {
    expect(() => filterAccounts(accounts, 'x')).not.toThrow();
  });
});

describe('role ordering', () => {
  it('ranks admin above creator above member above nothing', () => {
    expect(roleRank(['member'])).toBeLessThan(roleRank(['creator']));
    expect(roleRank(['creator', 'member'])).toBeLessThan(roleRank(['admin']));
    expect(roleRank([])).toBeLessThan(roleRank(['member']));
  });

  it('compareByRoles sorts highest role first, then by name', () => {
    const sorted = [...accounts].sort(compareByRoles);
    expect(sorted.map((a) => a.id)).toEqual([1, 2, 3, 4]);
  });
});
