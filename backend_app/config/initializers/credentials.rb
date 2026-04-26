# frozen_string_literal: true

# Single boundary for ENV-based credential reads.
#
# After this file runs:
#   - Each credential-consuming module has its credentials cached on class state.
#   - Sensitive values are removed from ENV via ENV.delete, so raw `ENV[...]`
#     reads elsewhere in the process return nil.
#
# To override credentials in tests, call `<Module>.setup(...)` directly with
# test values — do not mutate ENV.
#
# Called from `require_app.rb` in phase 3, after `config/` (phase 1) and
# `app/` (phase 2) — so `Tyto::Api` is defined, `ENV` is populated by Figaro,
# and the consumer classes (`AuthToken::Gateway`, `FileStorage`) exist.

Tyto::AuthToken::Gateway.setup(key: ENV.delete('JWT_KEY'))

Tyto::FileStorage.setup(
  aws: {
    bucket: ENV.delete('S3_BUCKET'),
    region: ENV.delete('S3_REGION'),
    access_key_id: ENV.delete('S3_ACCESS_KEY_ID'),
    secret_access_key: ENV.delete('S3_SECRET_ACCESS_KEY')
  },
  local: {
    root: ENV.delete('LOCAL_STORAGE_ROOT'),
    signing_key: ENV.delete('LOCAL_STORAGE_SIGNING_KEY'),
    base_url: ENV.delete('LOCAL_STORAGE_BASE_URL')
  }
)
