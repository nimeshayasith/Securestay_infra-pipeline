-- ============================================================
-- SecureStay Unified PostgreSQL Schema
-- Applied once to the "securestay" database after RDS is ready
-- Run via: scripts/run-migrations.sh  OR  a Kubernetes Job
-- Schema mirrors the local postgres.yaml ConfigMap exactly.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- AUTH SERVICE — users table
CREATE TABLE IF NOT EXISTS users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name     VARCHAR(120) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT         NOT NULL,   -- bcrypt hash, never plaintext
    role          VARCHAR(20)  NOT NULL DEFAULT 'CUSTOMER',
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_users_role CHECK (role IN ('CUSTOMER', 'ADMIN'))
);

-- BOOKING SERVICE — hotels, rooms, bookings
CREATE TABLE IF NOT EXISTS hotels (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(150) NOT NULL,
    city        VARCHAR(100) NOT NULL,
    address     TEXT         NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_hotels_name_city_address UNIQUE (name, city, address)
);

CREATE TABLE IF NOT EXISTS rooms (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    hotel_id        UUID          NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
    room_number     VARCHAR(20)   NOT NULL,
    room_type       VARCHAR(50)   NOT NULL,
    price_per_night NUMERIC(10,2) NOT NULL,
    capacity        INTEGER       NOT NULL,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_room_number_per_hotel   UNIQUE (hotel_id, room_number),
    CONSTRAINT chk_room_price_non_negative CHECK (price_per_night >= 0),
    CONSTRAINT chk_room_capacity_positive  CHECK (capacity > 0)
);

CREATE TABLE IF NOT EXISTS bookings (
    id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID          NOT NULL REFERENCES users(id)  ON DELETE RESTRICT,
    room_id        UUID          NOT NULL REFERENCES rooms(id)  ON DELETE RESTRICT,
    check_in_date  DATE          NOT NULL,
    check_out_date DATE          NOT NULL,
    total_amount   NUMERIC(10,2) NOT NULL,
    status         VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    guest_count    INTEGER       NOT NULL,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_booking_dates              CHECK (check_out_date > check_in_date),
    CONSTRAINT chk_booking_amount_non_negative CHECK (total_amount >= 0),
    CONSTRAINT chk_booking_guest_count_positive CHECK (guest_count > 0),
    CONSTRAINT chk_booking_status             CHECK (status IN ('PENDING', 'CONFIRMED', 'CANCELLED', 'FAILED'))
);

-- PAYMENT SERVICE
-- Raw card numbers are NEVER stored (PCI-DSS) — only masked_card_number
CREATE TABLE IF NOT EXISTS payments (
    id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id            UUID          NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    amount                NUMERIC(10,2) NOT NULL,
    currency              VARCHAR(10)   NOT NULL DEFAULT 'USD',
    payment_method        VARCHAR(30)   NOT NULL,
    transaction_reference VARCHAR(100)  NOT NULL UNIQUE,
    status                VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    masked_card_number    VARCHAR(25),
    processed_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_payment_amount_non_negative CHECK (amount >= 0),
    CONSTRAINT chk_payment_status CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('CARD', 'CASH', 'WALLET'))
);

-- NOTIFICATION SERVICE — replaces MongoDB entirely
-- Stores all consumed RabbitMQ events as durable log records
CREATE TABLE IF NOT EXISTS notification_logs (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    routing_key VARCHAR(255) NOT NULL,
    event_type  VARCHAR(100) NOT NULL,
    payload     JSONB        NOT NULL,   -- full RabbitMQ event payload
    status      VARCHAR(50)  NOT NULL DEFAULT 'delivered',
    received_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_hotels_city          ON hotels(city);
CREATE INDEX IF NOT EXISTS idx_rooms_hotel_id        ON rooms(hotel_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id      ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_room_id      ON bookings(room_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status       ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_payments_status       ON payments(status);
CREATE INDEX IF NOT EXISTS idx_notification_received ON notification_logs(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_type     ON notification_logs(event_type);

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO hotels (name, city, address, description)
VALUES
    ('SecureStay Colombo Central', 'Colombo', '12 Main Street, Colombo',  'Business hotel in the city center'),
    ('SecureStay Kandy Hills',     'Kandy',   '44 Lake Road, Kandy',      'Scenic hotel near Kandy Lake')
ON CONFLICT (name, city, address) DO NOTHING;

INSERT INTO rooms (hotel_id, room_number, room_type, price_per_night, capacity)
SELECT id, '101', 'STANDARD', 75.00, 2
FROM hotels WHERE name = 'SecureStay Colombo Central'
ON CONFLICT DO NOTHING;

INSERT INTO rooms (hotel_id, room_number, room_type, price_per_night, capacity)
SELECT id, '102', 'DELUXE', 120.00, 2
FROM hotels WHERE name = 'SecureStay Colombo Central'
ON CONFLICT DO NOTHING;

INSERT INTO rooms (hotel_id, room_number, room_type, price_per_night, capacity)
SELECT id, '201', 'DELUXE', 120.00, 3
FROM hotels WHERE name = 'SecureStay Kandy Hills'
ON CONFLICT DO NOTHING;

INSERT INTO rooms (hotel_id, room_number, room_type, price_per_night, capacity)
SELECT id, '202', 'STANDARD', 75.00, 2
FROM hotels WHERE name = 'SecureStay Kandy Hills'
ON CONFLICT DO NOTHING;
