/*******************************************************************************
 * db_initializer.cpp — FlexiStore Manager
 *
 * Creates the `flexistore` database and all 9 core tables if they do not exist.
 *
 * Table creation order respects foreign-key dependencies:
 *   1. users             (no FK)
 *   2. clients            (no FK)
 *   3. products           (no FK)
 *   4. invoices           (FK → clients, users)
 *   5. invoice_items      (FK → invoices, products)
 *   6. installments       (FK → clients, invoices)
 *   7. installment_payments (FK → installments, users)
 *   8. inventory_logs     (FK → products, users)
 *   9. transaction_logs   (FK → users)
 ******************************************************************************/

#include "db_initializer.h"
#include "db_connection_pool.h"
#include "db_config.h"

#include <iostream>
#include <string>
#include <vector>
using namespace std;
// ═════════════════════════════════════════════════════════════════════════════
// SQL Statements
// ═════════════════════════════════════════════════════════════════════════════

static const char* SQL_CREATE_DATABASE =
    "CREATE DATABASE IF NOT EXISTS flexistore "
    "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci";

static const char* SQL_USE_DATABASE =
    "USE flexistore";

// ── Table: users ─────────────────────────────────────────────────────────────
static const char* SQL_CREATE_USERS =
    "CREATE TABLE IF NOT EXISTS users ("
    "  id             INT AUTO_INCREMENT PRIMARY KEY,"
    "  name           VARCHAR(100)  NOT NULL,"
    "  username       VARCHAR(50)   NOT NULL UNIQUE,"
    "  password_hash  VARCHAR(255)  NOT NULL,"
    "role ENUM('admin', 'cashier', 'manager') NOT NULL DEFAULT 'cashier',"
    "  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    "  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: clients ───────────────────────────────────────────────────────────
static const char* SQL_CREATE_CLIENTS =
    "CREATE TABLE IF NOT EXISTS clients ("
    "  id             INT AUTO_INCREMENT PRIMARY KEY,"
    "  name           VARCHAR(100)  NOT NULL,"
    "  phone          VARCHAR(20)   NOT NULL UNIQUE,"
    "  email          VARCHAR(100)  DEFAULT NULL,"
    "  address        VARCHAR(255)  DEFAULT NULL,"
    "  notes          TEXT          DEFAULT NULL,"
    "  total_debt     DECIMAL(12,2) NOT NULL DEFAULT 0.00,"
    "  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    "  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: products ──────────────────────────────────────────────────────────
static const char* SQL_CREATE_PRODUCTS =
    "CREATE TABLE IF NOT EXISTS products ("
    "  id              INT AUTO_INCREMENT PRIMARY KEY,"
    "  barcode         VARCHAR(50)   NOT NULL UNIQUE,"
    "  name            VARCHAR(150)  NOT NULL,"
    "  category        VARCHAR(100)  NOT NULL DEFAULT 'General',"
    "  purchase_price  DECIMAL(10,2) NOT NULL DEFAULT 0.00,"
    "  selling_price   DECIMAL(10,2) NOT NULL DEFAULT 0.00,"
    "  stock_quantity  INT           NOT NULL DEFAULT 0,"
    "  status          ENUM('active','inactive') NOT NULL DEFAULT 'active',"
    "  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    "  updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: invoices ──────────────────────────────────────────────────────────
static const char* SQL_CREATE_INVOICES =
    "CREATE TABLE IF NOT EXISTS invoices ("
    "  id              INT AUTO_INCREMENT PRIMARY KEY,"
    "  client_id       INT           DEFAULT NULL,"
    "  user_id         INT           NOT NULL,"
    "  total_amount    DECIMAL(12,2) NOT NULL DEFAULT 0.00,"
    "  net_amount      DECIMAL(12,2) NOT NULL DEFAULT 0.00,"
    "  payment_type    ENUM('cash','installment','return') NOT NULL DEFAULT 'cash',"
    "  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    "  CONSTRAINT fk_invoices_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,"
    "  CONSTRAINT fk_invoices_user   FOREIGN KEY (user_id)   REFERENCES users(id)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: invoice_items ─────────────────────────────────────────────────────
static const char* SQL_CREATE_INVOICE_ITEMS =
    "CREATE TABLE IF NOT EXISTS invoice_items ("
    "  id              INT AUTO_INCREMENT PRIMARY KEY,"
    "  invoice_id      INT           NOT NULL,"
    "  product_id      INT           NOT NULL,"
    "  quantity         INT           NOT NULL DEFAULT 1,"
    "  unit_price      DECIMAL(10,2) NOT NULL DEFAULT 0.00,"
    "  CONSTRAINT fk_items_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,"
    "  CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(id)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: installments ──────────────────────────────────────────────────────
static const char* SQL_CREATE_INSTALLMENTS =
    "CREATE TABLE IF NOT EXISTS installments ("
    "  id                  INT AUTO_INCREMENT PRIMARY KEY,"
    "  client_id           INT           NOT NULL,"
    "  invoice_id          INT           NOT NULL,"
    "  total_amount        DECIMAL(12,2) NOT NULL DEFAULT 0.00,"
    "  remaining_amount    DECIMAL(12,2) NOT NULL DEFAULT 0.00,"
    "  months              INT           NOT NULL DEFAULT 1,"
    "  monthly_installment DECIMAL(10,2) NOT NULL DEFAULT 0.00,"
    "  status              ENUM('active','completed','cancelled') NOT NULL DEFAULT 'active',"
    "  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
    "  CONSTRAINT fk_inst_client  FOREIGN KEY (client_id)  REFERENCES clients(id),"
    "  CONSTRAINT fk_inst_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(id)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: installment_payments ──────────────────────────────────────────────
static const char* SQL_CREATE_INSTALLMENT_PAYMENTS =
    "CREATE TABLE IF NOT EXISTS installment_payments ("
    "  id               INT AUTO_INCREMENT PRIMARY KEY,"
    "  installment_id   INT           NOT NULL,"
    "  user_id          INT           NOT NULL,"
    "  amount_paid      DECIMAL(10,2) NOT NULL DEFAULT 0.00,"
    "  payment_date     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,"
    "  CONSTRAINT fk_payment_inst FOREIGN KEY (installment_id) REFERENCES installments(id) ON DELETE CASCADE,"
    "  CONSTRAINT fk_payment_user FOREIGN KEY (user_id)        REFERENCES users(id)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: inventory_logs ────────────────────────────────────────────────────
static const char* SQL_CREATE_INVENTORY_LOGS =
    "CREATE TABLE IF NOT EXISTS inventory_logs ("
    "  id               INT AUTO_INCREMENT PRIMARY KEY,"
    "  product_id       INT          NOT NULL,"
    "  user_id          INT          NOT NULL,"
    "  action_type      VARCHAR(50)  NOT NULL,"
    "  quantity_changed INT          NOT NULL DEFAULT 0,"
    "  created_at       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,"
    "  CONSTRAINT fk_invlog_product FOREIGN KEY (product_id) REFERENCES products(id),"
    "  CONSTRAINT fk_invlog_user    FOREIGN KEY (user_id)    REFERENCES users(id)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ── Table: transaction_logs ──────────────────────────────────────────────────
static const char* SQL_CREATE_TRANSACTION_LOGS =
    "CREATE TABLE IF NOT EXISTS transaction_logs ("
    "  id            INT AUTO_INCREMENT PRIMARY KEY,"
    "  user_id       INT            NOT NULL,"
    "  action_type   VARCHAR(50)    NOT NULL,"
    "  amount        DECIMAL(12,2)  NOT NULL DEFAULT 0.00,"
    "  created_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,"
    "  CONSTRAINT fk_txlog_user FOREIGN KEY (user_id) REFERENCES users(id)"
    ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

// ═════════════════════════════════════════════════════════════════════════════
// Ordered list of all CREATE TABLE statements (respects FK dependencies)
// ═════════════════════════════════════════════════════════════════════════════
static const vector<const char*> TABLE_CREATION_STATEMENTS = {
    SQL_CREATE_USERS,
    SQL_CREATE_CLIENTS,
    SQL_CREATE_PRODUCTS,
    SQL_CREATE_INVOICES,
    SQL_CREATE_INVOICE_ITEMS,
    SQL_CREATE_INSTALLMENTS,
    SQL_CREATE_INSTALLMENT_PAYMENTS,
    SQL_CREATE_INVENTORY_LOGS,
    SQL_CREATE_TRANSACTION_LOGS
};

static const vector<const char*> TABLE_NAMES = {
    "users",
    "clients",
    "products",
    "invoices",
    "invoice_items",
    "installments",
    "installment_payments",
    "inventory_logs",
    "transaction_logs"
};

// ═════════════════════════════════════════════════════════════════════════════
// Exported Function: initialize_database()
// ═════════════════════════════════════════════════════════════════════════════
extern "C" {

FLEXISTORE_EXPORT int initialize_database() {
    try {
        auto& pool = flexistore::DBConnectionPool::getInstance();
        auto conn = pool.getConnection();

        if (!conn) {
            cerr << "[db_initializer] ERROR — Could not acquire DB connection." << endl;
            return FFI_ERROR_DB_CONNECTION;
        }

        // RAII — ensure connection always returns to pool
        struct ConnGuard {
            flexistore::DBConnectionPool& p;
            std::unique_ptr<sql::Connection> c;
            ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
        } guard{pool, std::move(conn)};

        // ── Step 1: Create the database if it doesn't exist ──────────────
        {
            unique_ptr<sql::Statement> stmt(guard.c->createStatement());
            stmt->execute(SQL_CREATE_DATABASE);
            cout << "[db_initializer] Database 'flexistore' ensured." << endl;
        }

        // ── Step 2: Switch to the flexistore database ────────────────────
        {
            unique_ptr<sql::Statement> stmt(guard.c->createStatement());
            stmt->execute(SQL_USE_DATABASE);
        }

        // ── Step 3: Create all 9 tables in dependency order ──────────────
        for (size_t i = 0; i < TABLE_CREATION_STATEMENTS.size(); ++i) {
            unique_ptr<sql::Statement> stmt(guard.c->createStatement());
            stmt->execute(TABLE_CREATION_STATEMENTS[i]);
            cout << "[db_initializer] Table '" << TABLE_NAMES[i] << "' ensured." << endl;
        }

        // ── Step 3.1: Run schema migrations (e.g., missing category column) ──
        try {
            unique_ptr<sql::Statement> alter_stmt(guard.c->createStatement());
            alter_stmt->execute("ALTER TABLE products ADD COLUMN category VARCHAR(100) NOT NULL DEFAULT 'General' AFTER name");
            cout << "[db_initializer] Migration: Added 'category' column to products table." << endl;
        } catch (sql::SQLException& e) {
            // 1060 = Duplicate column name (already exists)
            if (e.getErrorCode() != 1060) {
                cout << "[db_initializer] Warning on ALTER TABLE products: " << e.what() << endl;
            }
        }

        // ── Step 4: Seed default users if users table is empty ────
        {
            unique_ptr<sql::Statement> stmt(guard.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT COUNT(*) AS cnt FROM users"
            ));

            if (rs->next() && rs->getInt("cnt") == 0) {
                unique_ptr<sql::Statement> insert_stmt(guard.c->createStatement());
                insert_stmt->execute(
                    "INSERT INTO users (name, username, password_hash, role) VALUES "
                    "('System Admin', 'admin', 'admin123', 'admin'), "
                    "('Cashier One', 'cashier', '123456', 'cashier'), "
                    "('Inventory Manager', 'store_mng', 'store123', 'manager')"
                );
                cout << "[db_initializer] Default users seeded from SQL schema." << endl;
            }
        }

        // ── Step 5: Seed default products so Team 7 Audit tests pass FK constraint ────
        {
            unique_ptr<sql::Statement> stmt(guard.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT COUNT(*) AS cnt FROM products"
            ));

            if (rs->next() && rs->getInt("cnt") == 0) {
                unique_ptr<sql::Statement> insert_stmt(guard.c->createStatement());
                insert_stmt->execute(
                    "INSERT INTO products (id, barcode, name, category, purchase_price, selling_price, stock_quantity, status) VALUES "
                    "(1, '1234567890123', 'Dummy Product', 'General', 10.00, 15.00, 100, 'active')"
                );
                cout << "[db_initializer] Dummy product seeded for FFI testing." << endl;
            }
        }

        cout << "[db_initializer] ✔ Database initialization complete." << endl;
        return FFI_SUCCESS;
    }
    catch (const sql::SQLException& e) {
        std::cerr << "[db_initializer] SQL ERROR — " << e.what()
                << " (code: " << e.getErrorCode()
                << ", state: " << e.getSQLState() << ")" << std::endl;
        return FFI_ERROR_DB_INIT;
    }
    catch (const std::exception& e) {
        std::cerr << "[db_initializer] ERROR — " << e.what() << std::endl;
        return FFI_ERROR_DB_INIT;
    }
}
}
