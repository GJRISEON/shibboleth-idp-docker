-- Shibboleth IdP 5.x JDBC Storage Tables

-- Drop existing objects if they exist
DROP INDEX IF EXISTS context_expires_idx;
DROP INDEX IF EXISTS expires_idx;
DROP TABLE IF EXISTS StorageRecords;

-- Create fresh StorageRecords table
CREATE TABLE StorageRecords (
    context varchar(255) NOT NULL,
    id varchar(255) NOT NULL,
    expires bigint DEFAULT NULL,
    value text NOT NULL,
    version bigint NOT NULL DEFAULT 1,
    PRIMARY KEY (context, id)
);

-- Create indexes
CREATE INDEX context_expires_idx ON StorageRecords (context, expires);
CREATE INDEX expires_idx ON StorageRecords (expires);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE StorageRecords TO shibboleth;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO shibboleth;