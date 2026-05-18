CREATE DATABASE IF NOT EXISTS momo_sms_analyzer
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE momo_sms_analyzer;

DROP TABLE IF EXISTS system_logs;
DROP TABLE IF EXISTS transaction_tags;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS transaction_categories;
DROP TABLE IF EXISTS uploaded_files;
DROP TABLE IF EXISTS users;


CREATE TABLE users (
    id              INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique user identifier',
    full_name       VARCHAR(100)    NOT NULL                            COMMENT 'Full legal name of the user',
    phone_number    VARCHAR(20)     NOT NULL UNIQUE                     COMMENT 'MoMo-registered phone number (E.164 format)',
    email           VARCHAR(100)    UNIQUE                              COMMENT 'Optional email address',
    password        VARCHAR(200)    NOT NULL                            COMMENT 'Bcrypt-hashed password',
    role            ENUM('admin','analyst','viewer') NOT NULL
                                    DEFAULT 'viewer'                    COMMENT 'Access control role',
    is_active       TINYINT(1)      NOT NULL DEFAULT 1                  COMMENT '1 = active, 0 = deactivated account',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Account creation timestamp',
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP         COMMENT 'Last profile update timestamp'
                        
) ENGINE=InnoDB COMMENT='Registered system users and their access roles';

-- Indexes
CREATE INDEX idx_users_role       ON users(role);
CREATE INDEX idx_users_is_active  ON users(is_active);
CREATE INDEX idx_users_created_at ON users(created_at);


CREATE TABLE transaction_categories (
    id              INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Category identifier',
    category_name   VARCHAR(50)     NOT NULL UNIQUE                     COMMENT 'Human-readable category label',
    description     TEXT                                                COMMENT 'Detailed description of this category',
    is_income       TINYINT(1)      NOT NULL DEFAULT 0                  COMMENT '1 = income type, 0 = expense/neutral',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Category creation timestamp',

    CONSTRAINT chk_category_name_not_empty CHECK (CHAR_LENGTH(TRIM(category_name)) > 0)
) ENGINE=InnoDB COMMENT='Transaction category definitions (Incoming, Transfer, Withdrawal, etc.)';

CREATE INDEX idx_categories_income ON transaction_categories(is_income);


CREATE TABLE uploaded_files (
    id              INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT             UNSIGNED NOT NULL,
    filename        VARCHAR(255)    NOT NULL                            ,
    file_size_kb    DECIMAL(10,2)                                       ,
    storage_path    VARCHAR(500)    NOT NULL                            ,
    parse_status    ENUM('pending','processing','completed','failed')
                                    NOT NULL DEFAULT 'pending'          COMMENT 'Current parsing pipeline status',
    records_parsed  INT             UNSIGNED DEFAULT 0                  COMMENT 'Number of transactions extracted',
    error_message   TEXT                                                COMMENT 'Parsing error detail if failed',
    uploaded_at     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Upload timestamp',

    CONSTRAINT fk_file_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_file_size CHECK (file_size_kb IS NULL OR file_size_kb > 0)
) ENGINE=InnoDB COMMENT='Uploaded XML files and their processing status';

CREATE INDEX idx_files_user_id     ON uploaded_files(user_id);
CREATE INDEX idx_files_parse_status ON uploaded_files(parse_status);
CREATE INDEX idx_files_uploaded_at  ON uploaded_files(uploaded_at);


CREATE TABLE transactions (
    id                  INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Transaction identifier',
    sender_id           INT             UNSIGNED                            COMMENT 'FK → users.id (NULL if external sender)',
    receiver_id         INT             UNSIGNED                            COMMENT 'FK → users.id (NULL if external receiver)',
    category_id         INT             UNSIGNED NOT NULL                   COMMENT 'FK → transaction_categories.id',
    file_id             INT             UNSIGNED                            COMMENT 'FK → uploaded_files.id (source file)',

    -- Financial fields
    amount              DECIMAL(12,2)   NOT NULL                            COMMENT 'Transaction amount in RWF',
    fee                 DECIMAL(12,2)   NOT NULL DEFAULT 0.00               COMMENT 'Transaction fee charged',
    balance_after       DECIMAL(12,2)                                       COMMENT 'Account balance after transaction',

    -- Classification
    transaction_type    ENUM(
                            'Incoming',
                            'Transfer',
                            'Withdrawal',
                            'Payment',
                            'Airtime',
                            'Bank_Deposit',
                            'Bundle_Purchase'
                        ) NOT NULL                                          COMMENT 'SMS-derived transaction type',
    transaction_status  ENUM('Pending','Completed','Failed')
                                        NOT NULL DEFAULT 'Completed'        COMMENT 'Processing outcome',

    -- Identifiers from SMS
    external_transaction_id VARCHAR(100) UNIQUE                             COMMENT 'MoMo-issued transaction reference ID',
    sender_name         VARCHAR(100)                                        COMMENT 'Name from SMS when sender is external',
    receiver_name       VARCHAR(100)                                        COMMENT 'Name from SMS when receiver is external',

    -- Timestamps
    transaction_date    DATETIME        NOT NULL                            COMMENT 'Actual transaction datetime from SMS',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Record insertion timestamp',
    updated_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP         COMMENT 'Last update timestamp',

    -- Raw data
    raw_message         TEXT            NOT NULL                            COMMENT 'Original unprocessed SMS body',

    -- Constraints
    CONSTRAINT chk_amount_positive  CHECK (amount > 0),
    CONSTRAINT chk_fee_non_negative CHECK (fee >= 0),

    CONSTRAINT fk_txn_sender   FOREIGN KEY (sender_id)
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_txn_receiver FOREIGN KEY (receiver_id)
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_txn_category FOREIGN KEY (category_id)
        REFERENCES transaction_categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_file     FOREIGN KEY (file_id)
        REFERENCES uploaded_files(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Processed MoMo transactions extracted from SMS XML exports';

-- Indexes for common query patterns
CREATE INDEX idx_txn_sender_id        ON transactions(sender_id);
CREATE INDEX idx_txn_receiver_id      ON transactions(receiver_id);
CREATE INDEX idx_txn_category_id      ON transactions(category_id);
CREATE INDEX idx_txn_file_id          ON transactions(file_id);
CREATE INDEX idx_txn_type             ON transactions(transaction_type);
CREATE INDEX idx_txn_status           ON transactions(transaction_status);
CREATE INDEX idx_txn_date             ON transactions(transaction_date);
CREATE INDEX idx_txn_amount           ON transactions(amount);
-- Composite index for analytics: monthly summaries by type
CREATE INDEX idx_txn_date_type        ON transactions(transaction_date, transaction_type);
-- Composite index for user-specific history queries
CREATE INDEX idx_txn_sender_date      ON transactions(sender_id, transaction_date);


-- TABLE: tags
-- Free-form labels users can apply to transactions
CREATE TABLE tags (
    id              INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Tag identifier',
    tag_name        VARCHAR(50)     NOT NULL UNIQUE                     COMMENT 'Unique tag label',
    created_by      INT             UNSIGNED                            COMMENT 'FK → users.id (creator)',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Tag creation timestamp',

    CONSTRAINT fk_tag_creator FOREIGN KEY (created_by)
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_tag_not_empty CHECK (CHAR_LENGTH(TRIM(tag_name)) > 0)
) ENGINE=InnoDB COMMENT='User-defined tags for flexible transaction labelling';

CREATE INDEX idx_tags_created_by ON tags(created_by);


-- TABLE: transaction_tags  (junction — resolves M:N)
-- Links transactions to tags (many-to-many)
CREATE TABLE transaction_tags (
    transaction_id  INT             UNSIGNED NOT NULL COMMENT 'FK → transactions.id',
    tag_id          INT             UNSIGNED NOT NULL COMMENT 'FK → tags.id',
    tagged_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When the tag was applied',
    tagged_by       INT             UNSIGNED                           COMMENT 'FK → users.id (who applied the tag)',

    PRIMARY KEY (transaction_id, tag_id),

    CONSTRAINT fk_tt_transaction FOREIGN KEY (transaction_id)
        REFERENCES transactions(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tt_tag FOREIGN KEY (tag_id)
        REFERENCES tags(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tt_tagger FOREIGN KEY (tagged_by)
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='Junction table: many-to-many between transactions and tags';

CREATE INDEX idx_tt_tag_id    ON transaction_tags(tag_id);
CREATE INDEX idx_tt_tagged_by ON transaction_tags(tagged_by);


-- TABLE: system_logs
-- Audit trail for all data processing events
CREATE TABLE system_logs (
    id              INT             UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Log entry identifier',
    transaction_id  INT             UNSIGNED                            COMMENT 'FK → transactions.id (nullable)',
    user_id         INT             UNSIGNED                            COMMENT 'FK → users.id (actor, nullable)',
    action_type     VARCHAR(100)    NOT NULL                            COMMENT 'Event type (e.g. PARSE, INSERT, DELETE)',
    log_message     TEXT            NOT NULL                            COMMENT 'Human-readable event description',
    status          ENUM('Success','Warning','Error')
                                    NOT NULL DEFAULT 'Success'          COMMENT 'Outcome of the logged action',
    ip_address      VARCHAR(45)                                         COMMENT 'IPv4 or IPv6 of the request origin',
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Log entry timestamp',

    CONSTRAINT fk_log_transaction FOREIGN KEY (transaction_id)
        REFERENCES transactions(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_log_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB COMMENT='System-wide audit log for processing and user actions';

CREATE INDEX idx_logs_transaction_id ON system_logs(transaction_id);
CREATE INDEX idx_logs_user_id        ON system_logs(user_id);
CREATE INDEX idx_logs_action_type    ON system_logs(action_type);
CREATE INDEX idx_logs_status         ON system_logs(status);
CREATE INDEX idx_logs_created_at     ON system_logs(created_at);


-- VIEWS for common analytics queries
-- Monthly income vs expense summary
CREATE OR REPLACE VIEW vw_monthly_summary AS
SELECT
    DATE_FORMAT(t.transaction_date, '%Y-%m')    AS month,
    c.category_name,
    t.transaction_type,
    COUNT(*)                                    AS transaction_count,
    SUM(t.amount)                               AS total_amount,
    SUM(t.fee)                                  AS total_fees,
    AVG(t.amount)                               AS avg_amount
FROM transactions t
JOIN transaction_categories c ON t.category_id = c.id
WHERE t.transaction_status = 'Completed'
GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m'), c.category_name, t.transaction_type;

-- Per-user transaction summary
CREATE OR REPLACE VIEW vw_user_transaction_summary AS
SELECT
    u.id                                        AS user_id,
    u.full_name,
    u.phone_number,
    COUNT(t.id)                                 AS total_transactions,
    SUM(CASE WHEN t.sender_id = u.id THEN t.amount ELSE 0 END)   AS total_sent,
    SUM(CASE WHEN t.receiver_id = u.id THEN t.amount ELSE 0 END) AS total_received,
    SUM(CASE WHEN t.sender_id = u.id THEN t.fee ELSE 0 END)      AS total_fees_paid
FROM users u
LEFT JOIN transactions t ON (t.sender_id = u.id OR t.receiver_id = u.id)
    AND t.transaction_status = 'Completed'
GROUP BY u.id, u.full_name, u.phone_number;


-- SEED DATA
-- Users (passwords are bcrypt placeholders)
INSERT INTO users (full_name, phone_number, email, password, role) VALUES
('Alice Uwimana',      '+250788100001', 'alice@example.rw',   '$2b$12$hash_alice',   'admin'),
('Bob Niyonzima',      '+250788100002', 'bob@example.rw',     '$2b$12$hash_bob',     'analyst'),
('Claire Mukamana',    '+250788100003', 'claire@example.rw',  '$2b$12$hash_claire',  'viewer'),
('David Habimana',     '+250788100004', 'david@example.rw',   '$2b$12$hash_david',   'viewer'),
('Esther Nyiraneza',   '+250788100005', 'esther@example.rw',  '$2b$12$hash_esther',  'analyst');

-- Transaction categories
INSERT INTO transaction_categories (category_name, description, is_income) VALUES
('Incoming Money',   'Money received from another MoMo account or bank',      1),
('Transfer',         'Peer-to-peer money transfer to another mobile number',   0),
('Withdrawal',       'Cash withdrawal at an agent or ATM',                     0),
('Payment',          'Merchant or bill payment via MoMo',                      0),
('Airtime',          'Airtime top-up purchase',                                0),
('Bank Deposit',     'Deposit from a linked bank account into MoMo wallet',    1),
('Bundle Purchase',  'Data or voice bundle purchase',                          0);

-- Uploaded files
INSERT INTO uploaded_files (user_id, filename, file_size_kb, storage_path, parse_status, records_parsed) VALUES
(1, 'momo_export_jan2025.xml', 245.50, '/uploads/2025/01/momo_export_jan2025.xml', 'completed', 87),
(1, 'momo_export_feb2025.xml', 198.30, '/uploads/2025/02/momo_export_feb2025.xml', 'completed', 64),
(2, 'momo_export_jan2025.xml', 320.10, '/uploads/2025/01/bob_momo_jan2025.xml',    'completed', 102),
(3, 'momo_sms_backup.xml',     89.00,  '/uploads/2025/03/claire_sms.xml',          'failed',    0),
(4, 'momo_march2025.xml',      156.75, '/uploads/2025/03/david_march.xml',         'processing',0);

-- Tags
INSERT INTO tags (tag_name, created_by) VALUES
('rent',        1),
('groceries',   1),
('salary',      2),
('utilities',   3),
('school-fees', 4),
('business',    2);

-- Transactions
INSERT INTO transactions
    (sender_id, receiver_id, category_id, file_id, amount, fee, balance_after,
     transaction_type, transaction_status, external_transaction_id,
     sender_name, receiver_name, transaction_date, raw_message)
VALUES
(1, 2, 2, 1, 50000.00, 250.00,  320000.00, 'Transfer',    'Completed', 'TXN20250115001',
 'Alice Uwimana',  'Bob Niyonzima',
 '2025-01-15 09:23:00',
 'RWF 50,000 transferred to Bob Niyonzima (0788100002). Fee: RWF 250. New balance: RWF 320,000. TxnID: TXN20250115001.'),

(NULL, 1, 1, 1, 200000.00, 0.00, 370000.00, 'Incoming',   'Completed', 'TXN20250115002',
 'RSSB Payments',  'Alice Uwimana',
 '2025-01-15 14:00:00',
 'You have received RWF 200,000 from RSSB Payments. New balance: RWF 370,000. TxnID: TXN20250115002.'),

(2, NULL, 3, 3, 30000.00, 300.00, 85000.00,  'Withdrawal', 'Completed', 'TXN20250118001',
 'Bob Niyonzima',  NULL,
 '2025-01-18 11:45:00',
 'Withdrawal of RWF 30,000. Fee: RWF 300. New balance: RWF 85,000. Agent: Kigali City. TxnID: TXN20250118001.'),

(3, NULL, 5, NULL, 2000.00, 0.00, 48000.00,  'Airtime',    'Completed', 'TXN20250120003',
 'Claire Mukamana', NULL,
 '2025-01-20 08:10:00',
 'RWF 2,000 airtime purchased for 0788100003. New balance: RWF 48,000. TxnID: TXN20250120003.'),

(4, 3, 4, 5, 15000.00, 100.00, 92000.00,  'Payment',    'Completed', 'TXN20250122001',
 'David Habimana', 'Kigali Water',
 '2025-01-22 16:55:00',
 'Payment of RWF 15,000 to Kigali Water. Fee: RWF 100. New balance: RWF 92,000. TxnID: TXN20250122001.'),

(1, NULL, 7, 1, 5000.00, 0.00, 315000.00, 'Bundle_Purchase','Completed','TXN20250123001',
 'Alice Uwimana',  'MTN Bundle',
 '2025-01-23 07:00:00',
 'RWF 5,000 bundle purchased. 3GB valid 30 days. New balance: RWF 315,000. TxnID: TXN20250123001.'),

(NULL, 2, 6, 3, 500000.00, 0.00, 615000.00,'Bank_Deposit','Completed','TXN20250125001',
 'BK Bank Account', 'Bob Niyonzima',
 '2025-01-25 10:30:00',
 'RWF 500,000 deposited from BK bank account ****4521. New balance: RWF 615,000. TxnID: TXN20250125001.'),

(2, 4, 2, 3, 75000.00, 375.00, 539625.00, 'Transfer',   'Completed', 'TXN20250126001',
 'Bob Niyonzima',  'David Habimana',
 '2025-01-26 12:20:00',
 'RWF 75,000 transferred to David Habimana (0788100004). Fee: RWF 375. New balance: RWF 539,625. TxnID: TXN20250126001.'),

(5, NULL, 3, NULL, 20000.00, 200.00, 130000.00,'Withdrawal','Failed',  'TXN20250128001',
 'Esther Nyiraneza',NULL,
 '2025-01-28 17:00:00',
 'Withdrawal of RWF 20,000 FAILED. Insufficient agent float. TxnID: TXN20250128001.'),

(1, 5, 2, 2, 100000.00, 500.00, 214500.00, 'Transfer',   'Completed', 'TXN20250201001',
 'Alice Uwimana',  'Esther Nyiraneza',
 '2025-02-01 09:00:00',
 'RWF 100,000 transferred to Esther Nyiraneza (0788100005). Fee: RWF 500. New balance: RWF 214,500. TxnID: TXN20250201001.');

-- Transaction tags
INSERT INTO transaction_tags (transaction_id, tag_id, tagged_by) VALUES
(1, 6, 1),   -- transfer → business
(2, 3, 1),   -- incoming → salary
(3, 1, 2),   -- withdrawal → rent
(5, 4, 4),   -- payment → utilities
(8, 6, 2),   -- transfer → business
(10,3, 1);   -- transfer → salary

-- System logs
INSERT INTO system_logs (transaction_id, user_id, action_type, log_message, status, ip_address) VALUES
(NULL, 1, 'FILE_UPLOAD',    'User uploaded momo_export_jan2025.xml (245 KB)',          'Success', '196.12.50.1'),
(NULL, 1, 'XML_PARSE',      'Parsed 87 SMS records from momo_export_jan2025.xml',      'Success', '196.12.50.1'),
(1,    1, 'TXN_INSERT',     'Transaction TXN20250115001 inserted successfully',         'Success', '196.12.50.1'),
(9,    5, 'TXN_FAILED',     'Transaction TXN20250128001 failed: agent float error',     'Error',   '196.12.50.9'),
(NULL, 2, 'FILE_UPLOAD',    'User uploaded bob_momo_jan2025.xml (320 KB)',              'Success', '196.12.51.2'),
(NULL, 2, 'XML_PARSE',      'Parsed 102 SMS records from bob_momo_jan2025.xml',         'Success', '196.12.51.2'),
(NULL, 3, 'FILE_UPLOAD',    'User uploaded claire_sms.xml (89 KB)',                     'Success', '196.12.52.3'),
(NULL, 3, 'XML_PARSE',      'Parse failed: malformed XML at line 44',                  'Error',   '196.12.52.3'),
(5,    4, 'TXN_INSERT',     'Transaction TXN20250122001 inserted successfully',         'Success', '196.12.53.4'),
(NULL, 1, 'REPORT_EXPORT',  'Monthly analytics report exported as PDF by Alice',       'Success', '196.12.50.1');


-- SAMPLE QUERIES demonstrating system functionality
-- Q1: Total completed transactions per category
SELECT
    c.category_name,
    COUNT(t.id)     AS transaction_count,
    SUM(t.amount)   AS total_rwf,
    SUM(t.fee)      AS total_fees
FROM transactions t
JOIN transaction_categories c ON t.category_id = c.id
WHERE t.transaction_status = 'Completed'
GROUP BY c.category_name
ORDER BY total_rwf DESC;

-- Q2: Monthly income vs expense for a specific user (user_id = 1)
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m')              AS month,
    SUM(CASE WHEN receiver_id = 1 THEN amount ELSE 0 END) AS income_rwf,
    SUM(CASE WHEN sender_id   = 1 THEN amount ELSE 0 END) AS expense_rwf,
    SUM(CASE WHEN sender_id   = 1 THEN fee    ELSE 0 END) AS fees_paid
FROM transactions
WHERE (sender_id = 1 OR receiver_id = 1)
  AND transaction_status = 'Completed'
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY month;

-- Q3: All transactions with tags (using junction table)
SELECT
    t.external_transaction_id,
    t.transaction_type,
    t.amount,
    t.transaction_date,
    GROUP_CONCAT(tg.tag_name ORDER BY tg.tag_name SEPARATOR ', ') AS tags
FROM transactions t
LEFT JOIN transaction_tags tt ON t.id = tt.transaction_id
LEFT JOIN tags tg              ON tt.tag_id = tg.id
WHERE t.transaction_status = 'Completed'
GROUP BY t.id
ORDER BY t.transaction_date DESC;

-- Q4: Failed transactions log
SELECT
    sl.created_at,
    u.full_name         AS actor,
    sl.action_type,
    sl.log_message,
    sl.ip_address
FROM system_logs sl
LEFT JOIN users u ON sl.user_id = u.id
WHERE sl.status = 'Error'
ORDER BY sl.created_at DESC;

-- Q5: Top senders by total amount transferred
SELECT
    u.full_name,
    u.phone_number,
    COUNT(t.id)     AS transfers_made,
    SUM(t.amount)   AS total_sent_rwf
FROM transactions t
JOIN users u ON t.sender_id = u.id
WHERE t.transaction_type = 'Transfer'
  AND t.transaction_status = 'Completed'
GROUP BY u.id
ORDER BY total_sent_rwf DESC
LIMIT 10;
