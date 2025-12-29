--liquibase formatted sql

--changeset oppleo:001
-- Schema for Oppleo database
CREATE TABLE users (
   username VARCHAR NOT NULL PRIMARY KEY,
   password VARCHAR,
   authenticated BOOLEAN DEFAULT false,
   shared_secret VARCHAR(256),
   enabled_2fa BOOLEAN DEFAULT false,
   enforce_local_2fa BOOLEAN DEFAULT false,
   avatar VARCHAR(256),
   web_auth_user_id VARCHAR(100),

   UNIQUE (username)
);


-- NOTE: use the createuser.py utility in src directory to create an admin user.
--       python3 createuser.py
-- Creates default admin user with password 'admin'
INSERT INTO users (
    username, 
    password, 
    authenticated, 
    shared_secret, 
    enabled_2fa,
    enforce_local_2fa,
    avatar,
    web_auth_user_id
) VALUES (
    'admin', 
    'pbkdf2:sha256:260000$XU6Oya4sFygvmTMg$c997b03bd810cbdb5521c2494b5e4f76bcd6d4db6eff996f5fd4c0ce7d1a127c', 
    true,  
    '',  
    false, 
    true, 
    'unknown.png',
    ''
);


-- Add WebAuthN Credentials table
CREATE TABLE webauthn_credentials (
    credential_owner VARCHAR NOT NULL,
    credential_id VARCHAR(256) NOT NULL,
    credential_name VARCHAR(100),
    aaguid VARCHAR(100),
    credential_backed_up BOOLEAN,
    credential_device_type VARCHAR(100),
    credential_public_key VARCHAR(256),
    credential_type VARCHAR(100),
    fmt VARCHAR(100),
    sign_count INT,
    user_verified BOOLEAN DEFAULT false,

    created_at TIMESTAMP DEFAULT NOW(),
    modified_at TIMESTAMP DEFAULT NOW(),
    origin VARCHAR(256),

    UNIQUE (credential_id, credential_public_key)
);


-- Charge session table
CREATE TABLE charge_session (
    id serial PRIMARY KEY,
    rfid VARCHAR(100) not null,
    start_value FLOAT,
    end_value FLOAT,
    start_time timestamp,
    end_time timestamp,
    tariff FLOAT,
    total_energy FLOAT,
    total_price FLOAT,
    km INT,
    trigger VARCHAR(12)
);


-- Energy device table
CREATE TABLE energy_device (
    energy_device_id VARCHAR(100) PRIMARY KEY not null,
    port_name VARCHAR(100),
    slave_address INT,
    baudrate INT,
    bytesize INT,
    parity CHAR(1),
    stopbits INT,
    serial_timeout FLOAT,
    simulate BOOLEAN,
    mode VARCHAR(10),
    close_port_after_each_call BOOLEAN,
    modbus_config VARCHAR(100),
    device_enabled BOOLEAN
);


-- Create the default device
INSERT INTO energy_device (
    energy_device_id,
    port_name,
    slave_address,
    baudrate,
    bytesize,
    parity,
    stopbits,
    serial_timeout,
    simulate,
    mode,
    close_port_after_each_call,
    modbus_config,
    device_enabled
) VALUES (
    'laadpaal_noord',  -- energy_device_id
    'dev/ttyUSB0',     -- port_name
    1,                 -- slave_address
    38400,             -- baudrate
    8,                 -- bytesize
    'N',               -- parity (N=None, E=Even, O=Odd)
    1,                 -- stopbits
    0.05,              -- serial_timeout in seconds
    true,              -- simulation enabled
    'rtu',             -- mode
    false,             -- close_port_after_each_call
    'SDM630v2',         -- modbus_config
    false              -- device_enabled
);


-- Link tables
ALTER TABLE charge_session ADD COLUMN energy_device_id VARCHAR(100) REFERENCES energy_device(energy_device_id);


-- Energy device measures table, contains the measurements from the energy device
CREATE TABLE energy_device_measures (
    id serial PRIMARY KEY,
    energy_device_id VARCHAR(100) references energy_device(energy_device_id),
    kwh_l1 FLOAT,
    kwh_l2 FLOAT,
    kwh_l3 FLOAT,
    a_l1 FLOAT,
    a_l2 FLOAT,
    a_l3 FLOAT,
    v_l1 FLOAT,
    v_l2 FLOAT,
    v_l3 FLOAT,
    p_l1 FLOAT,
    p_l2 FLOAT,
    p_l3 FLOAT,
    kw_total FLOAT,
    hz FLOAT,
    created_at timestamp
);


-- RFID table
CREATE TABLE rfid (
    rfid VARCHAR(100) not null,
    enabled BOOLEAN,
    created_at timestamp,
    last_used_at timestamp,
    name VARCHAR(100),
    vehicle_make VARCHAR(100),
    vehicle_model VARCHAR(100),
    license_plate VARCHAR(20),
    valid_from timestamp,
    valid_until timestamp,
    get_odometer BOOLEAN,
    vehicle_vin VARCHAR(100),
    vehicle_name VARCHAR(100),
    api_account VARCHAR(256)
);


-- Insert a default RFID for testing
INSERT INTO rfid (rfid, enabled, created_at) VALUES ('000000000000', false, now());


-- Charger configuration table
CREATE TABLE charger_config(
    charger_id VARCHAR (100) PRIMARY KEY,
    charger_name_text VARCHAR(100),
    charger_tariff FLOAT,
    modified_at TIMESTAMP,
    secret_key VARCHAR(100),
    wtf_csrf_secret_key VARCHAR(100),
    use_reloader BOOLEAN,
    factor_whkm INT,
    autosession_enabled BOOLEAN,
    autosession_minutes INT,
    autosession_energy FLOAT,
    autosession_condense_same_odometer BOOLEAN,
    pulseled_min INT,
    pulseled_max INT,
    gpio_mode VARCHAR(10),
    pin_led_red INT,
    pin_led_green INT,
    pin_led_blue INT,
    pin_buzzer INT,
    peakhours_offpeak_enabled BOOLEAN,
    peakhours_allow_peak_one_period BOOLEAN,
    pin_evse_switch INT,
    pin_evse_led INT,
    modbus_interval INT,
    webcharge_on_dashboard BOOLEAN,
    auth_webcharge BOOLEAN,
    restrict_dashboard_access BOOLEAN,
    restrict_menu BOOLEAN,
    allow_local_dashboard_access BOOLEAN,
    router_ip_address VARCHAR(255),
    receipt_prefix VARCHAR(20),
    backup_enabled BOOLEAN,
    backup_INTerval VARCHAR(1),
    backup_time_of_day TIME,
    backup_local_history INT,
    os_backup_enabled BOOLEAN,
    os_backup_type VARCHAR(20),
    smb_backup_username VARCHAR(60),
    smb_backup_password VARCHAR(100),
    smb_backup_servername_or_ip_address VARCHAR(20),
    smb_backup_service_name VARCHAR(200),
    smb_backup_remote_path VARCHAR(256),
    backup_interval_weekday VARCHAR(200),
    backup_interval_calday VARCHAR(300),
    os_backup_history INT,
    backup_success_timestamp TIMESTAMP,
    vehicle_data_on_dashboard BOOLEAN,
    wakeup_vehicle_on_data_request BOOLEAN,
    webauthn_expected_origin VARCHAR(200),
    behind_ssl_proxy BOOLEAN DEFAULT false      -- WebAuthN expected origin
);


-- Insert CHARger configuration
INSERT INTO charger_config (
    charger_id, 
    charger_name_text,
    charger_tariff, 
    modified_at, 
    secret_key, 
    wtf_csrf_secret_key, 
    use_reloader, 
    factor_whkm,
    autosession_enabled, 
    autosession_minutes, 
    autosession_energy, 
    autosession_condense_same_odometer,
    pulseled_min, 
    pulseled_max, 
    gpio_mode, 
    pin_led_red, 
    pin_led_green, 
    pin_led_blue, 
    pin_buzzer,
    peakhours_offpeak_enabled, 
    peakhours_allow_peak_one_period,
    pin_evse_switch,
    pin_evse_led,
    modbus_interval,
    webcharge_on_dashboard,
    auth_webcharge,
    restrict_dashboard_access,
    restrict_menu,
    allow_local_dashboard_access,
    router_ip_address,
    receipt_prefix,
    backup_enabled,
    backup_INTerval,
    backup_time_of_day,
    backup_local_history,
    os_backup_enabled,
    os_backup_type,
    smb_backup_username,
    smb_backup_password,
    smb_backup_servername_or_ip_address,
    smb_backup_service_name,
    smb_backup_remote_path,
    backup_interval_weekday,
    backup_interval_calday,
    os_backup_history,
    backup_success_timestamp,
    vehicle_data_on_dashboard,
    wakeup_vehicle_on_data_request,
    webauthn_expected_origin,
    behind_ssl_proxy
) VALUES (
    'laadpaal_noord',       -- CHARger_id             
    'laadpaal_noord',       -- CHARger_name_text             
    0.41,                 -- CHARger_tariff         
    current_timestamp,  -- modified_at      
    'abcdefghijklmnopqrstuvwxyz1234567890',     -- secret_key       
    'abcdefghijklmnopqrstuvwxyz1234567890',   -- wtf_csrf_secret_key
    false,            -- usereloader
    162,            -- factorwhkm   
    true,               -- autosessionenabled   
    90,           -- autosessionminutes 
    0.1,        -- autosessionenergy    
    true,            -- autosessioncondenseSameOdometer 
    3,                -- pulseledmin    
    98,          -- pulseledmax 
    'BCM',            -- gpiomode
    13,           -- pinledred
    12,      -- pinledgreen
    16,     -- pinledblue
    23,          -- pinbuzzer
    true,             -- peakhoursoffpeakenabled
    false,          -- peakhoursallowpeakoneperiod
    5,  -- pin_evse_switch
    6,   -- pin_evse_led
    10,   -- modbus_interval
    false,               -- webcharge_on_dashboard
    true,                 -- auth_webcharge
    false,                -- restrict_dashboard_access
    false,                 -- restrict_menu
    false,                -- allow_local_dashboard_access
    '10.0.0.1',            -- router_ip_address
    '00000',                -- receipt_prefix
    false,                -- backup_enabled
    'd',                   -- backup_INTerval
    '08:00:00',            -- backup_time_of_day
    5,                     -- backup_local_history
    false,                 -- os_backup_enabled
    '',                    -- os_backup_type
    '',                    -- smb_backup_username
    '',                    -- smb_backup_password
    '',                      -- smb_backup_servername_or_ip_address
    '',                      -- smb_backup_service_name
    '',                       -- smb_backup_remote_path
    '[false, false, false, false, false, false, false]',                       -- backup_interval_weekday
    '[false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]',                       -- backup_interval_calday
    5,                      -- os_backup_history
    '1970-01-01 00:00:00.000000',                   -- backup_success_timestamp
    false,                   -- vehicle_data_on_dashboard
    false,                    -- wakeup_vehicle_on_data_request
    '',                      -- webauthn_expected_origin
    false                    -- behind_ssl_proxy
);


-- Daltarief 
--      Meestal op weekdagen van 23.00 tot 7.00 uur en in weekenden en op feestdagen* de gehele dag. 
--      Op officiële feestdagen: Nieuwjaarsdag, Eerste Paasdag, Tweede Paasdag, Koningsdag, Hemelvaartsdag, Eerste Pinksterdag, Tweede Pinksterdag, Eerste Kerstdag en Tweede Kerstdag.

--      feestdag - datum
--      zon/zaterdag - weekdag
--      weekdag 23-07

--      Bijv. Monday   00:00-07:00 en 23:00-23:59
--      Recurring = same date each year. Pinksteren and Eastern change each year, Christmas and Kingsday are recurring on the same date

CREATE TABLE off_peak_hours (
   id serial PRIMARY KEY,
   weekday VARCHAR (20),
   holiday_day INT,
   holiday_month INT,
   holiday_year INT,
   recurring BOOLEAN,
   description VARCHAR(100),
   off_peak_start TIME NOT NULL,
   off_peak_end TIME NOT NULL
);


-- Weekday
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Monday', '00:00', '07:00', 'Maandag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Monday', '23:00', '23:59', 'Maandag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Tuesday', '00:00', '07:00', 'Dinsdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Tuesday', '23:00', '23:59', 'Dinsdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Wednesday', '00:00', '07:00', 'Woensdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Wednesday', '23:00', '23:59', 'Woensdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Thursday', '00:00', '07:00', 'Donderdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Thursday', '23:00', '23:59', 'Donderdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Friday', '00:00', '07:00', 'Vrijdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Friday', '23:00', '23:59', 'Vrijdag');


-- Weekend
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Saturday', '00:00', '23:59', 'Zaterdag');
INSERT INTO off_peak_hours (weekday, off_peak_start, off_peak_end, description) 
   VALUES ('Sunday', '00:00', '23:59', 'Zondag');


-- Nieuwjaarsdag
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (1, 1, 2026, '00:00', '23:59', 'Nieuwjaarsdag', true);
-- Tweede Paasdag
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (6, 4, 2026, '00:00', '23:59', 'Tweede Paasdag 2026', false);
-- Koningsdag
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (27, 4, 2026, '00:00', '23:59', 'Koningsdag', true);
-- Hemelvaartsdag
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (14, 5, 2026, '00:00', '23:59', 'Hemelvaartsdag 2026', false);
-- Tweede Pinksterdag
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (25, 5, 2026, '00:00', '23:59', 'Tweede Pinksterdag 2026', false);
-- Eerste Kerstdag
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (25, 12, 2026, '00:00', '23:59', 'Eerste Kerstdag', true);
-- Tweede Kerstdag.
INSERT INTO off_peak_hours (holiday_day, holiday_month, holiday_year, off_peak_start, off_peak_end, description, recurring) 
   VALUES (26, 12, 2026, '00:00', '23:59', 'Tweede Kerstdag', true);



-- Store json values by key string, used for teslapy en pipolestar cache
CREATE TABLE keyvaluestores (
    kvstore VARCHAR(256) NOT NULL,
    scope VARCHAR(256) NOT NULL,
    key VARCHAR(256) NOT NULL,
    value JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    modified_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (kvstore, scope, key)
);

