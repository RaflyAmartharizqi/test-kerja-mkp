-- ===============================================
-- E-TICKETING TRANSPORTASI PUBLIK - POSTGRESQL SCRIPT
-- ===============================================
-- Database: eticket_db
-- Version: PostgreSQL 13+
-- Created: 2025
-- ===============================================

-- Create database (run this separately as superuser)
-- CREATE DATABASE eticket_db;
-- \c eticket_db;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===============================================
-- DROP TABLES (for clean install)
-- ===============================================
DROP TABLE IF EXISTS offline_transactions CASCADE;
DROP TABLE IF EXISTS fare_matrix CASCADE;
DROP TABLE IF EXISTS journeys CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS gates CASCADE;
DROP TABLE IF EXISTS cards CASCADE;
DROP TABLE IF EXISTS terminal CASCADE;
DROP TABLE IF EXISTS admin CASCADE;

-- Drop custom types
DROP TYPE IF EXISTS transaction_type_enum CASCADE;
DROP TYPE IF EXISTS sync_status_enum CASCADE;
DROP TYPE IF EXISTS journey_status_enum CASCADE;
DROP TYPE IF EXISTS offline_sync_status_enum CASCADE;

-- ===============================================
-- CREATE CUSTOM TYPES
-- ===============================================
CREATE TYPE transaction_type_enum AS ENUM ('checkin', 'checkout');
CREATE TYPE sync_status_enum AS ENUM ('synced', 'pending', 'error');
CREATE TYPE journey_status_enum AS ENUM ('active', 'completed', 'incomplete', 'cancelled', 'penalty');
CREATE TYPE offline_sync_status_enum AS ENUM ('pending', 'synced', 'error', 'conflict');

-- ===============================================
-- TABLE: admin
-- ===============================================
CREATE TABLE admin (
    id_admin BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE admin IS 'Tabel admin sistem e-ticketing';
COMMENT ON COLUMN admin.id_admin IS 'ID unik admin';
COMMENT ON COLUMN admin.name IS 'Nama lengkap admin';
COMMENT ON COLUMN admin.username IS 'Username untuk login';
COMMENT ON COLUMN admin.password IS 'Password yang sudah di-hash';

-- ===============================================
-- TABLE: terminal
-- ===============================================
CREATE TABLE terminal (
    id_terminal BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE terminal IS 'Master data terminal transportasi publik';
COMMENT ON COLUMN terminal.id_terminal IS 'ID unik terminal';
COMMENT ON COLUMN terminal.name IS 'Nama terminal';
COMMENT ON COLUMN terminal.location IS 'Lokasi terminal';

-- ===============================================
-- TABLE: cards
-- ===============================================
CREATE TABLE cards (
    card_number BIGSERIAL PRIMARY KEY,
    balance DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE cards IS 'Master data kartu e-ticketing';
COMMENT ON COLUMN cards.card_number IS 'Nomor kartu unik';
COMMENT ON COLUMN cards.balance IS 'Saldo kartu dalam rupiah';
COMMENT ON COLUMN cards.status IS 'Status kartu (active, blocked, expired)';

-- Add check constraints
ALTER TABLE cards ADD CONSTRAINT chk_cards_balance CHECK (balance >= 0);
ALTER TABLE cards ADD CONSTRAINT chk_cards_status CHECK (status IN ('active', 'blocked', 'expired'));

-- ===============================================
-- TABLE: gates
-- ===============================================
CREATE TABLE gates (
    id_gates SERIAL PRIMARY KEY,
    id_terminal BIGINT NOT NULL REFERENCES terminal(id_terminal) ON DELETE CASCADE,
    gate_number VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'offline',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE gates IS 'Gate/gerbang validasi di setiap terminal';
COMMENT ON COLUMN gates.id_gates IS 'ID unik gate';
COMMENT ON COLUMN gates.id_terminal IS 'ID terminal tempat gate berada';
COMMENT ON COLUMN gates.gate_number IS 'Nomor gate (A1, A2, dll)';
COMMENT ON COLUMN gates.status IS 'Status gate (online, offline, error, maintenance)';

-- Add check constraint
ALTER TABLE gates ADD CONSTRAINT chk_gates_status CHECK (status IN ('online', 'offline', 'error', 'maintenance'));

-- ===============================================
-- TABLE: fare_matrix
-- ===============================================
CREATE TABLE fare_matrix (
    id SERIAL PRIMARY KEY,
    from_terminal BIGINT NOT NULL REFERENCES terminal(id_terminal),
    to_terminal BIGINT NOT NULL REFERENCES terminal(id_terminal),
    regular_fare DECIMAL(8,2) NOT NULL,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE fare_matrix IS 'Matrix tarif perjalanan antar terminal';
COMMENT ON COLUMN fare_matrix.from_terminal IS 'Terminal asal';
COMMENT ON COLUMN fare_matrix.to_terminal IS 'Terminal tujuan';
COMMENT ON COLUMN fare_matrix.regular_fare IS 'Tarif regular';
COMMENT ON COLUMN fare_matrix.effective_date IS 'Tanggal mulai berlaku';
COMMENT ON COLUMN fare_matrix.end_date IS 'Tanggal berakhir (NULL = aktif)';

-- Add check constraints
ALTER TABLE fare_matrix ADD CONSTRAINT chk_fare_positive CHECK (regular_fare > 0);
ALTER TABLE fare_matrix ADD CONSTRAINT chk_fare_dates CHECK (end_date IS NULL OR end_date >= effective_date);
ALTER TABLE fare_matrix ADD CONSTRAINT chk_fare_different_terminals CHECK (from_terminal != to_terminal);

-- ===============================================
-- TABLE: journeys
-- ===============================================
CREATE TABLE journeys (
    id_journey VARCHAR(32) PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    card_number BIGINT NOT NULL REFERENCES cards(card_number),
    origin_terminal BIGINT NOT NULL REFERENCES terminal(id_terminal),
    destination_terminal BIGINT NULL REFERENCES terminal(id_terminal),
    checkin_gate INTEGER NOT NULL REFERENCES gates(id_gates),
    checkout_gate INTEGER NULL REFERENCES gates(id_gates),
    checkin_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    checkout_time TIMESTAMP NULL,
    fare_charged DECIMAL(8,2) NULL,
    max_fare_held DECIMAL(8,2) NOT NULL,
    journey_status journey_status_enum NOT NULL DEFAULT 'active',
    travel_duration INTEGER NULL,
    created_offline BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE journeys IS 'Data perjalanan penumpang dari checkin hingga checkout';
COMMENT ON COLUMN journeys.id_journey IS 'UUID untuk setiap perjalanan';
COMMENT ON COLUMN journeys.card_number IS 'Nomor kartu yang digunakan';
COMMENT ON COLUMN journeys.origin_terminal IS 'Terminal asal';
COMMENT ON COLUMN journeys.destination_terminal IS 'Terminal tujuan';
COMMENT ON COLUMN journeys.checkin_time IS 'Waktu check-in';
COMMENT ON COLUMN journeys.checkout_time IS 'Waktu check-out';
COMMENT ON COLUMN journeys.fare_charged IS 'Tarif yang dikenakan';
COMMENT ON COLUMN journeys.max_fare_held IS 'Tarif maksimum yang di-hold saat checkin';
COMMENT ON COLUMN journeys.travel_duration IS 'Durasi perjalanan dalam menit';

-- Add check constraints
ALTER TABLE journeys ADD CONSTRAINT chk_journey_fare_positive CHECK (fare_charged IS NULL OR fare_charged >= 0);
ALTER TABLE journeys ADD CONSTRAINT chk_journey_max_fare_positive CHECK (max_fare_held > 0);
ALTER TABLE journeys ADD CONSTRAINT chk_journey_checkout_after_checkin CHECK (checkout_time IS NULL OR checkout_time >= checkin_time);

-- ===============================================
-- TABLE: transactions
-- ===============================================
CREATE TABLE transactions (
    id_transaction BIGSERIAL PRIMARY KEY,
    card_number BIGINT NOT NULL REFERENCES cards(card_number),
    id_journey VARCHAR(32) NULL REFERENCES journeys(id_journey),
    transaction_type transaction_type_enum NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    balance_before DECIMAL(10,2) NOT NULL,
    balance_after DECIMAL(10,2) NOT NULL,
    id_gates INTEGER NULL REFERENCES gates(id_gates),
    id_terminal BIGINT NULL REFERENCES terminal(id_terminal),
    reference_number VARCHAR(50) NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sync_status sync_status_enum NOT NULL DEFAULT 'synced',
    offline_created BOOLEAN NOT NULL DEFAULT FALSE,
    hash_signature VARCHAR(64) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add comment
COMMENT ON TABLE transactions IS 'Log semua transaksi kartu (checkin, checkout, topup, dll)';
COMMENT ON COLUMN transactions.id_transaction IS 'ID transaksi auto increment';
COMMENT ON COLUMN transactions.card_number IS 'Nomor kartu';
COMMENT ON COLUMN transactions.id_journey IS 'ID perjalanan untuk menghubungkan checkin-checkout';
COMMENT ON COLUMN transactions.amount IS 'Jumlah transaksi (+ untuk topup, - untuk pembayaran)';
COMMENT ON COLUMN transactions.balance_before IS 'Saldo sebelum transaksi';
COMMENT ON COLUMN transactions.balance_after IS 'Saldo setelah transaksi';
COMMENT ON COLUMN transactions.id_gates IS 'Gate tempat transaksi';
COMMENT ON COLUMN transactions.reference_number IS 'Nomor referensi untuk topup/refund';
COMMENT ON COLUMN transactions.hash_signature IS 'Hash untuk validasi integritas data';

-- Add check constraints
ALTER TABLE transactions ADD CONSTRAINT chk_trans_balance_positive CHECK (balance_before >= 0 AND balance_after >= 0);

-- ===============================================
-- TABLE: offline_transactions
-- ===============================================
CREATE TABLE offline_transactions (
    id BIGSERIAL PRIMARY KEY,
    id_gates INTEGER NOT NULL REFERENCES gates(id_gates),
    card_number BIGINT NOT NULL,
    transaction_data JSONB NOT NULL,
    transaction_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP NULL,
    sync_status offline_sync_status_enum NOT NULL DEFAULT 'pending',
    sync_attempts INTEGER NOT NULL DEFAULT 0,
    error_message TEXT NULL
);

-- Add comment
COMMENT ON TABLE offline_transactions IS 'Buffer transaksi offline sebelum disinkronisasi ke server';
COMMENT ON COLUMN offline_transactions.id_gates IS 'Gate tempat transaksi offline';
COMMENT ON COLUMN offline_transactions.card_number IS 'Nomor kartu dari transaksi offline';
COMMENT ON COLUMN offline_transactions.transaction_data IS 'Data transaksi dalam format JSON';
COMMENT ON COLUMN offline_transactions.transaction_hash IS 'Hash untuk validasi integritas';
COMMENT ON COLUMN offline_transactions.created_at IS 'Waktu transaksi offline dibuat';
COMMENT ON COLUMN offline_transactions.synced_at IS 'Waktu data berhasil disinkronisasi';
COMMENT ON COLUMN offline_transactions.sync_attempts IS 'Jumlah percobaan sinkronisasi';

-- Add check constraint
ALTER TABLE offline_transactions ADD CONSTRAINT chk_offline_sync_attempts CHECK (sync_attempts >= 0);

-- ===============================================
-- CREATE INDEXES
-- ===============================================

-- Admin indexes
CREATE INDEX idx_admin_username ON admin(username);
CREATE INDEX idx_admin_created_at ON admin(created_at);

-- Terminal indexes
CREATE INDEX idx_terminal_name ON terminal(name);
CREATE INDEX idx_terminal_location ON terminal(location);

-- Cards indexes
CREATE INDEX idx_cards_status ON cards(status);
CREATE INDEX idx_cards_balance ON cards(balance);
CREATE INDEX idx_cards_created_at ON cards(created_at);

-- Gates indexes
CREATE INDEX idx_gates_terminal ON gates(id_terminal);
CREATE INDEX idx_gates_status ON gates(status);
CREATE INDEX idx_gates_gate_number ON gates(gate_number);

-- Fare matrix indexes
CREATE UNIQUE INDEX idx_fare_route_date ON fare_matrix(from_terminal, to_terminal, effective_date);
CREATE INDEX idx_fare_effective ON fare_matrix(effective_date);
CREATE INDEX idx_fare_end_date ON fare_matrix(end_date);

-- Journeys indexes
CREATE INDEX idx_journeys_card ON journeys(card_number);
CREATE INDEX idx_journeys_status ON journeys(journey_status);
CREATE INDEX idx_journeys_route ON journeys(origin_terminal, destination_terminal);
CREATE INDEX idx_journeys_checkin_time ON journeys(checkin_time);
CREATE INDEX idx_journeys_card_status ON journeys(card_number, journey_status);
CREATE INDEX idx_journeys_created_at ON journeys(created_at);

-- Transactions indexes
CREATE INDEX idx_transactions_card ON transactions(card_number);
CREATE INDEX idx_transactions_journey ON transactions(id_journey);
CREATE INDEX idx_transactions_gate ON transactions(id_gates);
CREATE INDEX idx_transactions_time ON transactions(timestamp);
CREATE INDEX idx_transactions_sync ON transactions(sync_status);
CREATE INDEX idx_transactions_card_time ON transactions(card_number, timestamp);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);

-- Offline transactions indexes
CREATE INDEX idx_offline_trans_gate ON offline_transactions(id_gates);
CREATE INDEX idx_offline_trans_sync ON offline_transactions(sync_status);
CREATE INDEX idx_offline_trans_created ON offline_transactions(created_at);
CREATE INDEX idx_offline_trans_gate_sync ON offline_transactions(id_gates, sync_status);
CREATE INDEX idx_offline_trans_card ON offline_transactions(card_number);

-- ===============================================
-- CREATE TRIGGERS FOR updated_at
-- ===============================================

-- Function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for all tables with updated_at
CREATE TRIGGER update_admin_updated_at BEFORE UPDATE ON admin FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_terminal_updated_at BEFORE UPDATE ON terminal FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cards_updated_at BEFORE UPDATE ON cards FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_gates_updated_at BEFORE UPDATE ON gates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_fare_matrix_updated_at BEFORE UPDATE ON fare_matrix FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_journeys_updated_at BEFORE UPDATE ON journeys FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===============================================
-- FUNCTIONS AND PROCEDURES
-- ===============================================

-- Function to get current active fare
CREATE OR REPLACE FUNCTION get_active_fare(p_from_terminal BIGINT, p_to_terminal BIGINT)
RETURNS DECIMAL(8,2) AS $$
DECLARE
    fare_amount DECIMAL(8,2);
BEGIN
    SELECT regular_fare INTO fare_amount
    FROM fare_matrix
    WHERE from_terminal = p_from_terminal
      AND to_terminal = p_to_terminal
      AND effective_date <= CURRENT_DATE
      AND (end_date IS NULL OR end_date >= CURRENT_DATE)
    ORDER BY effective_date DESC
    LIMIT 1;
    
    RETURN COALESCE(fare_amount, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to calculate journey duration
CREATE OR REPLACE FUNCTION calculate_journey_duration(p_journey_id VARCHAR(32))
RETURNS INTEGER AS $$
DECLARE
    duration_minutes INTEGER;
BEGIN
    SELECT EXTRACT(EPOCH FROM (checkout_time - checkin_time))/60 INTO duration_minutes
    FROM journeys
    WHERE id_journey = p_journey_id
      AND checkout_time IS NOT NULL;
    
    RETURN duration_minutes;
END;
$$ LANGUAGE plpgsql;

-- Function to update journey duration on checkout
CREATE OR REPLACE FUNCTION update_journey_duration()
RETURNS TRIGGER AS $$
BEGIN
    -- Update travel duration when checkout_time is set
    IF NEW.checkout_time IS NOT NULL AND OLD.checkout_time IS NULL THEN
        NEW.travel_duration = EXTRACT(EPOCH FROM (NEW.checkout_time - NEW.checkin_time))/60;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for journey duration update
CREATE TRIGGER trigger_update_journey_duration
    BEFORE UPDATE ON journeys
    FOR EACH ROW EXECUTE FUNCTION update_journey_duration();

-- ===============================================
-- INSERT SAMPLE DATA
-- ===============================================

-- Insert default admin
INSERT INTO admin (name, username, password) VALUES 
('Administrator', 'admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'); -- password: password

-- Insert terminals
INSERT INTO terminal (name, location) VALUES 
('Terminal A', 'Jakarta Pusat'),
('Terminal B', 'Jakarta Selatan'),
('Terminal C', 'Jakarta Barat'),
('Terminal D', 'Jakarta Utara'),
('Terminal E', 'Jakarta Timur');

-- Insert gates for each terminal
INSERT INTO gates (id_terminal, gate_number, status) VALUES 
(1, 'A1', 'online'),
(1, 'A2', 'online'),
(2, 'B1', 'online'),
(2, 'B2', 'online'),
(2, 'B3', 'online'),
(3, 'C1', 'online'),
(3, 'C2', 'online'),
(4, 'D1', 'online'),
(5, 'E1', 'online'),
(5, 'E2', 'online');

-- Insert fare matrix (sample data)
INSERT INTO fare_matrix (from_terminal, to_terminal, regular_fare) VALUES 
(1, 2, 5000.00),
(1, 3, 8000.00),
(1, 4, 12000.00),
(1, 5, 15000.00),
(2, 1, 5000.00),
(2, 3, 6000.00),
(2, 4, 10000.00),
(2, 5, 13000.00),
(3, 1, 8000.00),
(3, 2, 6000.00),
(3, 4, 7000.00),
(3, 5, 9000.00),
(4, 1, 12000.00),
(4, 2, 10000.00),
(4, 3, 7000.00),
(4, 5, 8000.00),
(5, 1, 15000.00),
(5, 2, 13000.00),
(5, 3, 9000.00),
(5, 4, 8000.00);

-- Insert sample cards
INSERT INTO cards (balance, status) VALUES 
(50000.00, 'active'),
(25000.00, 'active'),
(100000.00, 'active'),
(10000.00, 'active'),
(75000.00, 'active');

-- ===============================================
-- VIEWS FOR REPORTING
-- ===============================================

-- View for daily transaction summary
CREATE VIEW daily_transaction_summary AS
SELECT 
    DATE(timestamp) as transaction_date,
    id_terminal,
    t.name as terminal_name,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN transaction_type = 'checkin' THEN 1 ELSE 0 END) as total_checkins,
    SUM(CASE WHEN transaction_type = 'checkout' THEN 1 ELSE 0 END) as total_checkouts,
    SUM(ABS(amount)) as total_revenue
FROM transactions tr
LEFT JOIN gates g ON tr.id_gates = g.id_gates
LEFT JOIN terminal t ON g.id_terminal = t.id_terminal
WHERE tr.transaction_type IN ('checkin', 'checkout')
GROUP BY DATE(timestamp), id_terminal, t.name
ORDER BY transaction_date DESC, id_terminal;

-- View for active journeys
CREATE VIEW active_journeys AS
SELECT 
    j.id_journey,
    j.card_number,
    j.checkin_time,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - j.checkin_time))/60 as minutes_elapsed,
    t1.name as origin_terminal_name,
    t1.location as origin_location,
    g1.gate_number as checkin_gate_number,
    j.max_fare_held
FROM journeys j
LEFT JOIN terminal t1 ON j.origin_terminal = t1.id_terminal
LEFT JOIN gates g1 ON j.checkin_gate = g1.id_gates
WHERE j.journey_status = 'active'
ORDER BY j.checkin_time;

-- ===============================================
-- SECURITY & PERMISSIONS
-- ===============================================

-- Create roles (optional)
-- CREATE ROLE eticket_admin;
-- CREATE ROLE eticket_gate;
-- CREATE ROLE eticket_readonly;

-- Grant permissions
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO eticket_admin;
-- GRANT SELECT, INSERT, UPDATE ON transactions, journeys, offline_transactions TO eticket_gate;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO eticket_readonly;

-- ===============================================
-- MAINTENANCE QUERIES
-- ===============================================

-- Query to clean up old offline transactions (older than 30 days)
-- DELETE FROM offline_transactions 
-- WHERE sync_status = 'synced' 
--   AND synced_at < CURRENT_DATE - INTERVAL '30 days';

-- Query to find incomplete journeys (older than 24 hours)
-- SELECT * FROM journeys 
-- WHERE journey_status = 'active' 
--   AND checkin_time < CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- ===============================================
-- DATABASE INFORMATION
-- ===============================================

-- Show table sizes
-- SELECT 
--     schemaname,
--     tablename,
--     attname,
--     n_distinct,
--     correlation
-- FROM pg_stats
-- WHERE schemaname = 'public'
-- ORDER BY tablename, attname;

COMMIT;