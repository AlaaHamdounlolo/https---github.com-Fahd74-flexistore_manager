#include "audit_logger.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include <mutex>
#include <iostream>
#include <memory>
#include <cstring>

namespace {
    std::mutex audit_mutex;

    // RAII guard for db connection
    struct ConnGuard {
        flexistore::DBConnectionPool& p;
        std::unique_ptr<sql::Connection> c;
        ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
    };
}

extern "C" {

FLEXISTORE_EXPORT void log_inventory_change(int product_id, int user_id, const char* action_type, int quantity_changed) {
    std::lock_guard<std::mutex> lock(audit_mutex);
    try {
        if (!action_type) return;

        auto& pool = flexistore::DBConnectionPool::getInstance();
        ConnGuard guard{pool, pool.getConnection()};
        if (!guard.c) {
            std::cerr << "[Audit] Error: Failed to acquire DB connection for inventory log." << std::endl;
            return;
        }

        std::unique_ptr<sql::PreparedStatement> pstmt(guard.c->prepareStatement(
            "INSERT INTO inventory_logs (product_id, user_id, action_type, quantity_changed) "
            "VALUES (?, ?, ?, ?)"
        ));

        pstmt->setInt(1, product_id);
        pstmt->setInt(2, user_id);
        pstmt->setString(3, action_type);
        pstmt->setInt(4, quantity_changed);

        pstmt->executeUpdate();

    } catch (const sql::SQLException& e) {
        std::cerr << "[Audit] SQLException in log_inventory_change: " << e.what() << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "[Audit] Exception in log_inventory_change: " << e.what() << std::endl;
    }
}

FLEXISTORE_EXPORT void log_transaction(int user_id, const char* action_type, double amount) {
    std::lock_guard<std::mutex> lock(audit_mutex);
    try {
        if (!action_type) return;

        auto& pool = flexistore::DBConnectionPool::getInstance();
        ConnGuard guard{pool, pool.getConnection()};
        if (!guard.c) {
            std::cerr << "[Audit] Error: Failed to acquire DB connection for transaction log." << std::endl;
            return;
        }

        std::unique_ptr<sql::PreparedStatement> pstmt(guard.c->prepareStatement(
            "INSERT INTO transaction_logs (user_id, action_type, amount) "
            "VALUES (?, ?, ?)"
        ));

        pstmt->setInt(1, user_id);
        pstmt->setString(2, action_type);
        pstmt->setDouble(3, amount);

        pstmt->executeUpdate();

    } catch (const sql::SQLException& e) {
        std::cerr << "[Audit] SQLException in log_transaction: " << e.what() << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "[Audit] Exception in log_transaction: " << e.what() << std::endl;
    }
}

FLEXISTORE_EXPORT const char* get_inventory_logs() {
    std::lock_guard<std::mutex> lock(audit_mutex);
    try {
        auto& pool = flexistore::DBConnectionPool::getInstance();
        ConnGuard guard{pool, pool.getConnection()};
        if (!guard.c) {
            return flexistore::allocate_ffi_string("[{\"error\":\"DB Connection Failed\"}]");
        }

        std::unique_ptr<sql::Statement> stmt(guard.c->createStatement());
        std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
            "SELECT id, product_id, user_id, action_type, quantity_changed, created_at "
            "FROM inventory_logs ORDER BY created_at DESC LIMIT 50"
        ));

        std::string json_str = flexistore::JsonBuilder::result_set_to_json(rs.get());
        return flexistore::allocate_ffi_string(json_str);

    } catch (const sql::SQLException& e) {
        std::string err_msg = std::string("[{\"error\":\"SQLException: ") + e.what() + "\"}]";
        return flexistore::allocate_ffi_string(err_msg);
    } catch (const std::exception& e) {
        std::string err_msg = std::string("[{\"error\":\"Exception: ") + e.what() + "\"}]";
        return flexistore::allocate_ffi_string(err_msg);
    }
}

FLEXISTORE_EXPORT const char* get_transaction_logs() {
    std::lock_guard<std::mutex> lock(audit_mutex);
    try {
        auto& pool = flexistore::DBConnectionPool::getInstance();
        ConnGuard guard{pool, pool.getConnection()};
        if (!guard.c) {
            return flexistore::allocate_ffi_string("[{\"error\":\"DB Connection Failed\"}]");
        }

        std::unique_ptr<sql::Statement> stmt(guard.c->createStatement());
        std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
            "SELECT id, user_id, action_type, "
            "CAST(amount AS CHAR) AS amount, "
            "CAST(created_at AS CHAR) AS created_at "
            "FROM transaction_logs ORDER BY created_at DESC LIMIT 50"
        ));

        // Build JSON manually — avoids result_set_to_json which triggers
        // MySQL Connector internal DECIMAL handling and corrupts Debug CRT heap
        flexistore::JsonBuilder builder;
        builder.start_array();
        while (rs->next()) {
            builder.start_object();
            builder.add_int("id", rs->getInt("id"));
            builder.add_int("user_id", rs->getInt("user_id"));
            builder.add_string("action_type", rs->getString("action_type"));

            // amount was CAST to CHAR in SQL — parse safely in C++
            std::string amount_str = rs->getString("amount");
            try {
                builder.add_double("amount", std::stod(amount_str));
            } catch (...) {
                builder.add_double("amount", 0.0);
            }

            builder.add_string("created_at", rs->getString("created_at"));
            builder.end_object();
        }
        builder.end_array();

        return flexistore::allocate_ffi_string(builder.build());

    } catch (const sql::SQLException& e) {
        std::string err_msg = std::string("[{\"error\":\"SQLException: ") + e.what() + "\"}]";
        return flexistore::allocate_ffi_string(err_msg);
    } catch (const std::exception& e) {
        std::string err_msg = std::string("[{\"error\":\"Exception: ") + e.what() + "\"}]";
        return flexistore::allocate_ffi_string(err_msg);
    }
}

} // extern "C"
