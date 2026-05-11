#include "installment_functions.h"
#include "../core/db_connection_pool.h"
#include "../audit/audit_logger.h"

#include <mysql/jdbc.h>
#include <mutex>
#include <iostream>
#include <memory>
#include <cmath>

using namespace std;

namespace {
    std::mutex installment_mutex;

    // RAII guard for db connection
    struct ConnGuard {
        flexistore::DBConnectionPool& p;
        unique_ptr<sql::Connection> c;
        ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
    };
}

extern "C" {

FLEXISTORE_EXPORT int create_installment_plan(
    int user_id,
    int client_id,
    int invoice_id,
    double total_amount,
    int months
) {
    std::lock_guard<std::mutex> lock(installment_mutex);

    // ── Input validation ──────────────────────────────────────────────────
    if (months <= 0) return FFI_ERROR_INST_INVALID_MONTHS;
    if (total_amount <= 0.0) return FFI_ERROR_INST_INVALID_AMOUNT;
    if (client_id <= 0) return FFI_ERROR_POS_INVALID_CLIENT;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    sql::Connection* conn = guard.c.get();

    try {
        conn->setAutoCommit(false);

        // ── Calculate monthly installment ─────────────────────────────────
        double monthly = std::round((total_amount / months) * 100.0) / 100.0;

        // ── Step 1: Insert installment plan ───────────────────────────────
        unique_ptr<sql::PreparedStatement> plan_stmt(conn->prepareStatement(
            "INSERT INTO installments "
            "(client_id, invoice_id, total_amount, remaining_amount, months, monthly_installment, status) "
            "VALUES (?, ?, ?, ?, ?, ?, 'active')"
        ));
        plan_stmt->setInt(1, client_id);
        plan_stmt->setInt(2, invoice_id);
        plan_stmt->setDouble(3, total_amount);
        plan_stmt->setDouble(4, total_amount); // remaining = total initially
        plan_stmt->setInt(5, months);
        plan_stmt->setDouble(6, monthly);
        plan_stmt->executeUpdate();

        // ── Step 2: Update client's total_debt ────────────────────────────
        unique_ptr<sql::PreparedStatement> debt_stmt(conn->prepareStatement(
            "UPDATE clients SET total_debt = total_debt + ? WHERE id = ?"
        ));
        debt_stmt->setDouble(1, total_amount);
        debt_stmt->setInt(2, client_id);
        int affected = debt_stmt->executeUpdate();

        if (affected == 0) {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_NOT_FOUND; // Client doesn't exist
        }

        // ── COMMIT ────────────────────────────────────────────────────────
        conn->commit();
        conn->setAutoCommit(true);

        // ── Audit log (non-critical) ──────────────────────────────────────
        log_transaction(user_id, "INSTALLMENT_PLAN_CREATED", total_amount);

        return FFI_SUCCESS;

    } catch (sql::SQLException& e) {
        std::cerr << "[Installments] SQLException: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_DB_QUERY;
    } catch (std::exception& e) {
        std::cerr << "[Installments] Exception: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_UNKNOWN;
    }
}

} // extern "C"
