-- Shibboleth IdP 5.x JDBC Storage Tables

CREATE TABLE IF NOT EXISTS shibpid_context_value (
    context varchar(255) NOT NULL,
    id varchar(255) NOT NULL,
    expires bigint DEFAULT NULL,
    value text NOT NULL,
    version bigint NOT NULL DEFAULT 1,
    PRIMARY KEY (context, id)
);

CREATE INDEX IF NOT EXISTS shibpid_context_value_expires_idx ON shibpid_context_value (context, expires);
CREATE INDEX IF NOT EXISTS shibpid_context_value_version_idx ON shibpid_context_value (version);

-- Additional table for JDBC storage service
CREATE TABLE IF NOT EXISTS shibpid_lock_storage (
    context varchar(255) NOT NULL,
    id varchar(255) NOT NULL,
    expires bigint DEFAULT NULL,
    PRIMARY KEY (context, id)
);

CREATE INDEX IF NOT EXISTS shibpid_lock_storage_expires_idx ON shibpid_lock_storage (expires);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE shibpid_context_value TO shibboleth;
GRANT ALL PRIVILEGES ON TABLE shibpid_lock_storage TO shibboleth;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO shibboleth;