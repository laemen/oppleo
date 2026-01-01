--liquibase formatted sql

--changeset oppleo:002

--          add primary key to rfid table
ALTER TABLE public.rfid ADD PRIMARY KEY (rfid);