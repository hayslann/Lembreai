-- LembreAI: somente métricas e direitos de acesso, nunca textos de lembretes.
CREATE TABLE IF NOT EXISTS usage_daily (
 day TEXT PRIMARY KEY NOT NULL,
 requests INTEGER NOT NULL DEFAULT 0,
 successes INTEGER NOT NULL DEFAULT 0,
 errors INTEGER NOT NULL DEFAULT 0,
 input_tokens INTEGER NOT NULL DEFAULT 0,
 output_tokens INTEGER NOT NULL DEFAULT 0,
 image_requests INTEGER NOT NULL DEFAULT 0,
 updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS users (
 uid TEXT PRIMARY KEY NOT NULL,
 email TEXT,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 last_active_at TEXT,
 plan TEXT NOT NULL DEFAULT 'free',
 credit_balance INTEGER NOT NULL DEFAULT 0,
 account_status TEXT NOT NULL DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS credit_ledger (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 user_uid TEXT NOT NULL REFERENCES users(uid),
 event_type TEXT NOT NULL,
 delta INTEGER NOT NULL,
 reference_id TEXT NOT NULL UNIQUE,
 actor TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS purchase_records (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 user_uid TEXT NOT NULL REFERENCES users(uid),
 provider TEXT NOT NULL,
 provider_transaction_id TEXT UNIQUE,
 price_cents INTEGER,
 currency TEXT NOT NULL DEFAULT 'BRL',
 plan TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'pending',
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_last_active ON users(last_active_at);
CREATE INDEX IF NOT EXISTS idx_credits_user_created ON credit_ledger(user_uid,created_at);
