--liquibase formatted sql

--changeset oppleo:003

-- set created_at column to not null to allow indexing
ALTER TABLE energy_device_measures
ALTER COLUMN created_at SET NOT NULL;

-- add index to energy_device_measures table
-- index on energy_device_id and created_at descending for faster retrieval of latest measures per device
CREATE INDEX idx_edm_device_created_at_desc
ON energy_device_measures (energy_device_id, created_at DESC);

-- set created_at column to not null to allow indexing
-- end_time needs to be NULL for open sessions
ALTER TABLE charge_session
ALTER COLUMN start_time SET NOT NULL;

-- Prima performance zonder extra indexen
-- Alleen als je zeker wilt dat 'last N per user' instant is:
CREATE INDEX idx_charge_rfid_start_time_desc
ON charge_session (rfid, start_time DESC);