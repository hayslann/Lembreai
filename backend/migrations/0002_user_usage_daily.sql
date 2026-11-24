-- Per-user request and token totals. Never store prompts or reminder text.
ALTER TABLE credit_ledger ADD COLUMN expires_at TEXT;
CREATE TABLE IF NOT EXISTS usage_user_daily (
 day TEXT NOT NULL,
 user_uid TEXT NOT NULL REFERENCES users(uid),
 requests INTEGER NOT NULL DEFAULT 0,
 successes INTEGER NOT NULL DEFAULT 0,
 errors INTEGER NOT NULL DEFAULT 0,
 input_tokens INTEGER NOT NULL DEFAULT 0,
 output_tokens INTEGER NOT NULL DEFAULT 0,
 image_requests INTEGER NOT NULL DEFAULT 0,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(day,user_uid)
);
CREATE INDEX IF NOT EXISTS idx_user_usage_uid_day ON usage_user_daily(user_uid,day);
CREATE TABLE IF NOT EXISTS reward_sessions (
 custom_data TEXT PRIMARY KEY NOT NULL,
 user_uid TEXT NOT NULL REFERENCES users(uid),
 status TEXT NOT NULL DEFAULT 'pending',
 transaction_id TEXT UNIQUE,
 expires_at TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 completed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_reward_sessions_user_day ON reward_sessions(user_uid,created_at);
