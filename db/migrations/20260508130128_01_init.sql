-- migrate:up

CREATE TABLE auth_user (
  username TEXT PRIMARY KEY NOT NULL,
  password BLOB NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('root', 'admin', 'staff', 'user')),
  last_logged_in INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE auth_session (
  key TEXT PRIMARY KEY NOT NULL,
  username TEXT NOT NULL REFERENCES auth_user(username),
  revoked INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0, 1)),
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);


-- migrate:down

DROP TABLE IF EXISTS auth_session;
DROP TABLE IF EXISTS auth_user;
