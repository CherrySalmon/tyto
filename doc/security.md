# Cryptographic code conventions

## Rule

All cryptographic primitives go through **`Tyto::Security`**
(`backend_app/app/lib/security.rb`). Application code — services, gateways,
mappers, routes, rake tasks, specs — does not call `RbNaCl::*`,
`OpenSSL::HMAC`, `OpenSSL::Cipher`, `SecureRandom`, or any other crypto
library directly.

`Tyto::Security` is the single source of truth for:

- random-byte generation and uniqueness identifiers (`random_bytes`,
  `unique_id`)
- symmetric authenticated encryption (`Tyto::Security::Secret`)
- keyed message authentication (`Tyto::Security::Signer`)
- key generation for `secrets.yml` / ENV (`generate_secret_key`,
  `generate_signing_key`)

If a use case isn't covered (password hashing, asymmetric signatures,
KDFs, X.509, etc.), **add it to `Tyto::Security` first** with a spec, then
consume from there. Do not introduce a parallel crypto path.

## Why

1. **Audit surface is one file.** A reviewer changes one place to evaluate
   "what crypto does this codebase do?" and one place to swap libraries
   if a CVE or a stronger primitive lands.
2. **Intent-revealing, vendor-neutral names.** `Secret#encrypt(payload)`
   and `Signer#valid?(message, tag)` say what they do without dragging in
   the underlying library's vocabulary. Call sites stay readable and can
   keep working if the backing library changes.
3. **No crypto-library mixing.** Past versions of this codebase had
   `OpenSSL::HMAC` next to `RbNaCl::SecretBox` next to `SecureRandom` —
   three primitive sources, three bug surfaces. Convergence on one library
   is a guardrail.
4. **Defaults are baked in.** Constant-time tag comparison, random
   nonces, 32-byte keys — call sites can't accidentally skip them.

## What's in `Tyto::Security`

The names below are intentionally vendor-neutral. Application code should
not need to know which crypto library backs them, and the library can be
swapped without changing any call site.

```ruby
Tyto::Security.random_bytes(n)        # n raw random bytes (low-level primitive)
Tyto::Security.unique_id              # short string-safe unique identifier
Tyto::Security.unique_id(byte_count)  # — with explicit entropy
Tyto::Security.generate_secret_key    # base64-encoded key for Secret
Tyto::Security.generate_signing_key   # base64-encoded key for Signer

# Symmetric authenticated encryption
secret = Tyto::Security::Secret.new(key: raw_key_bytes)
blob = secret.encrypt(plaintext)      # binary blob; caller frames as needed
secret.decrypt(blob)                  # raises Secret::EncryptionError on tamper

# Keyed message authentication, constant-time verification
signer = Tyto::Security::Signer.new(key: raw_key_bytes)
tag = signer.sign(message)
signer.valid?(message, tag)           # boolean
```

Prefer `unique_id` over `random_bytes` whenever you just need a string-safe
identifier (test fixtures, dedupe keys, nonces inside a JSON payload).
`random_bytes` is a primitive — call sites that need raw bytes are usually
building their own crypto and should be reviewed.

## What's *outside* the rule

- **Non-cryptographic checksums** for caching / snapshot comparison
  (e.g., `Digest::MD5.hexdigest(rows.inspect)` in
  `backend_app/db/rehearsal.rb`) are fine. They're not security
  primitives. Comment the call site if intent could be confused.
- **Library internals.** Sequel, dry-types, JSON, etc. may call crypto
  themselves — that's not us calling crypto.

## Adding a new primitive

1. Write a spec in `backend_app/spec/lib/security_spec.rb` covering the
   happy path, failure modes, and constant-time properties (where
   relevant).
2. Implement in `backend_app/app/lib/security.rb`. Keep the wrapper
   minimal — `Tyto::Security` is a thin, named layer over the underlying
   library, not a framework.
3. Remove the now-redundant direct call from the consumer.
4. Run `bundle exec rake spec` and confirm the regression stays green.

## Setup state and key handling

- Keys live in `backend_app/config/secrets.yml` (and ENV in production).
- They are read **once** at boot by
  `backend_app/config/initializers/credentials.rb`, which calls
  `Tyto::AuthToken::Gateway.setup(key:)` and
  `Tyto::FileStorage.setup(aws:, local:)` and then `ENV.delete`s the
  underlying variables. Application code reads from the cached state on
  those modules — never from `ENV` directly.
- Tests inject test credentials via the same `setup` methods. Test code
  does not mutate `ENV`.

## Generating new keys

```bash
bundle exec rake generate:jwt_key                    # JWT_KEY for AuthToken
bundle exec rake generate:local_storage_signing_key  # dev/test only
```

Both call into `Tyto::Security`.

## Related files

- `backend_app/app/lib/security.rb` — the boundary
- `backend_app/spec/lib/security_spec.rb` — the contract
- `backend_app/app/infrastructure/auth/auth_token/gateway.rb` — consumer
  (uses `Secret`)
- `backend_app/app/infrastructure/file_storage/token_store.rb` — consumer
  (uses `Signer`)
- `backend_app/config/initializers/credentials.rb` — single ENV-reading boundary
