/*******************************************************************************
 * invoice_queries.cpp — FlexiStore Manager (Data Access Layer)
 *
 * SQL implementation for invoice and stock operations.
 * Uses MySQL Connector/C++ (JDBC API) against the FlexiStore schema.
 *
 * All functions receive an active sql::Connection* — the CALLER manages the
 * transaction lifecycle (BEGIN / COMMIT / ROLLBACK). This enables composing
 * multiple DAL calls into a single atomic transaction from the use-case layer.
 *
 * Table references (from db_initializer.cpp):
 *   products      — id, stock_quantity, selling_price, name, status
 *   invoices      — id, client_id, user_id, total_amount, net_amount, payment_type
 *   invoice_items — id, invoice_id, product_id, quantity, unit_price
 *   users         — id, name
 *   clients       — id, name
 ******************************************************************************/

#include "invoice_queries.h"
#include "../core/json_builder.h"

#include <mysql/jdbc.h>
#include <iostream>
#include <stdexcept>
#include <cstring>

using namespace std;

namespace flexistore {
namespace data {

// ═════════════════════════════════════════════════════════════════════════════
// Stock Operations
// ═════════════════════════════════════════════════════════════════════════════

int validateStock(sql::Connection* conn, int product_id, int required) {
    try {
        // SELECT ... FOR UPDATE acquires a row-level lock within the
        // caller's transaction, preventing concurrent overselling.
        unique_ptr<sql::PreparedStatement> stmt(conn->prepareStatement(
            "SELECT stock_quantity, status FROM products "
            "WHERE id = ? FOR UPDATE"
        ));
        stmt->setInt(1, product_id);
        unique_ptr<sql::ResultSet> rs(stmt->executeQuery());

        if (!rs->next()) {
            return FFI_ERROR_INV_PRODUCT_NOT_FOUND;  // -205
        }

        // Reject inactive products
        string status = rs->getString("status");
        if (status != "active") {
            return FFI_ERROR_INV_PRODUCT_NOT_FOUND;  // -205
        }

        int currentStock = rs->getInt("stock_quantity");
        if (currentStock < required) {
            return FFI_ERROR_POS_INSUFFICIENT_STOCK;  // -401
        }

        return FFI_SUCCESS;  // 0

    } catch (sql::SQLException& e) {
        cerr << "[DAL] validateStock SQL error: " << e.what()
             << " (code=" << e.getErrorCode() << ")" << endl;
        return FFI_ERROR_DB_QUERY;  // -3
    }
}

int updateStock(sql::Connection* conn, int product_id, int delta) {
    try {
        // Uses arithmetic UPDATE — delta can be negative (sale) or
        // positive (return/restock).
        //
        // Example:
        //   Sale of 3:   UPDATE products SET stock_quantity = stock_quantity + (-3) WHERE id = ?
        //   Return of 3: UPDATE products SET stock_quantity = stock_quantity + (3)  WHERE id = ?
        unique_ptr<sql::PreparedStatement> stmt(conn->prepareStatement(
            "UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?"
        ));
        stmt->setInt(1, delta);
        stmt->setInt(2, product_id);
        int affected = stmt->executeUpdate();

        if (affected == 0) {
            cerr << "[DAL] updateStock: no rows affected for product_id="
                 << product_id << endl;
            return FFI_ERROR_INV_PRODUCT_NOT_FOUND;  // -205
        }

        return FFI_SUCCESS;  // 0

    } catch (sql::SQLException& e) {
        cerr << "[DAL] updateStock SQL error: " << e.what()
             << " (code=" << e.getErrorCode() << ")" << endl;
        return FFI_ERROR_DB_QUERY;  // -3
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// Invoice Operations
// ═════════════════════════════════════════════════════════════════════════════

int saveFullInvoice(
    sql::Connection* conn,
    int user_id,
    int client_id,
    double total_amount,
    double net_amount,
    const string& payment_type,
    const vector<InvoiceItem>& items)
{
    try {
        // ── Step 1: Insert invoice header ─────────────────────────────────
        //
        // client_id = 0 means "Guest" → store as NULL so the FK doesn't
        // reference a non-existent row.
        unique_ptr<sql::PreparedStatement> invoiceStmt(conn->prepareStatement(
            "INSERT INTO invoices (client_id, user_id, total_amount, net_amount, payment_type) "
            "VALUES (?, ?, ?, ?, ?)"
        ));

        if (client_id > 0) {
            invoiceStmt->setInt(1, client_id);
        } else {
            invoiceStmt->setNull(1, sql::DataType::INTEGER);
        }
        invoiceStmt->setInt(2, user_id);
        invoiceStmt->setDouble(3, total_amount);
        invoiceStmt->setDouble(4, net_amount);
        invoiceStmt->setString(5, payment_type);
        invoiceStmt->executeUpdate();

        // ── Step 2: Retrieve the generated invoice_id ─────────────────────
        unique_ptr<sql::Statement> idStmt(conn->createStatement());
        unique_ptr<sql::ResultSet> idRs(idStmt->executeQuery(
            "SELECT LAST_INSERT_ID() AS id"
        ));

        int invoice_id = 0;
        if (idRs->next()) {
            invoice_id = idRs->getInt("id");
        }

        if (invoice_id <= 0) {
            cerr << "[DAL] saveFullInvoice: LAST_INSERT_ID returned "
                 << invoice_id << endl;
            return FFI_ERROR_POS_INVOICE_FAILED;  // -403
        }

        // ── Step 3: Insert each line item ─────────────────────────────────
        unique_ptr<sql::PreparedStatement> itemStmt(conn->prepareStatement(
            "INSERT INTO invoice_items (invoice_id, product_id, quantity, unit_price) "
            "VALUES (?, ?, ?, ?)"
        ));

        for (const auto& item : items) {
            itemStmt->setInt(1, invoice_id);
            itemStmt->setInt(2, item.product_id);
            itemStmt->setInt(3, item.quantity);
            itemStmt->setDouble(4, item.unit_price);
            itemStmt->executeUpdate();
        }

        return invoice_id;  // > 0 indicates success

    } catch (sql::SQLException& e) {
        cerr << "[DAL] saveFullInvoice SQL error: " << e.what()
             << " (code=" << e.getErrorCode() << ")" << endl;
        return FFI_ERROR_POS_INVOICE_FAILED;  // -403
    }
}

int findInvoiceById(sql::Connection* conn, int invoice_id, InvoiceRecord& record) {
    try {
        // ── Query 1: Invoice header with resolved client/cashier names ────
        //
        // LEFT JOIN on clients because client_id can be NULL (Guest).
        // INNER JOIN on users because user_id is always required.
        unique_ptr<sql::PreparedStatement> headerStmt(conn->prepareStatement(
            "SELECT "
            "  i.id, "
            "  i.client_id, "
            "  i.user_id, "
            "  i.total_amount, "
            "  i.net_amount, "
            "  i.payment_type, "
            "  i.created_at, "
            "  COALESCE(c.name, 'Guest') AS client_name, "
            "  u.name AS cashier_name "
            "FROM invoices i "
            "LEFT JOIN clients c ON i.client_id = c.id "
            "INNER JOIN users u ON i.user_id = u.id "
            "WHERE i.id = ?"
        ));
        headerStmt->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> headerRs(headerStmt->executeQuery());

        if (!headerRs->next()) {
            return FFI_ERROR_NOT_FOUND;  // -6
        }

        // Populate the record header
        record.id           = headerRs->getInt("id");
        record.client_id    = headerRs->isNull("client_id") ? 0 : headerRs->getInt("client_id");
        record.user_id      = headerRs->getInt("user_id");
        record.total_amount = headerRs->getDouble("total_amount");
        record.net_amount   = headerRs->getDouble("net_amount");
        record.payment_type = headerRs->getString("payment_type");
        record.client_name  = headerRs->getString("client_name");
        record.cashier_name = headerRs->getString("cashier_name");
        record.created_at   = headerRs->getString("created_at");

        // ── Query 2: Invoice line items with product names ────────────────
        unique_ptr<sql::PreparedStatement> itemsStmt(conn->prepareStatement(
            "SELECT "
            "  ii.product_id, "
            "  ii.quantity, "
            "  ii.unit_price, "
            "  p.name AS product_name "
            "FROM invoice_items ii "
            "INNER JOIN products p ON ii.product_id = p.id "
            "WHERE ii.invoice_id = ? "
            "ORDER BY ii.id ASC"
        ));
        itemsStmt->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> itemsRs(itemsStmt->executeQuery());

        record.items.clear();
        while (itemsRs->next()) {
            InvoiceItem item;
            item.product_id = itemsRs->getInt("product_id");
            item.quantity   = itemsRs->getInt("quantity");
            item.unit_price = itemsRs->getDouble("unit_price");
            record.items.push_back(item);
        }

        return FFI_SUCCESS;  // 0

    } catch (sql::SQLException& e) {
        cerr << "[DAL] findInvoiceById SQL error: " << e.what()
             << " (code=" << e.getErrorCode() << ")" << endl;
        return FFI_ERROR_DB_QUERY;  // -3
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// JSON Serialization
// ═════════════════════════════════════════════════════════════════════════════

const char* invoiceRecordToJson(const InvoiceRecord& record) {
    try {
        JsonBuilder jb;
        jb.start_object();

        jb.add_int("id", record.id);
        jb.add_int("client_id", record.client_id);
        jb.add_int("user_id", record.user_id);
        jb.add_double("total_amount", record.total_amount);
        jb.add_double("net_amount", record.net_amount);
        jb.add_string("payment_type", record.payment_type);
        jb.add_string("client_name", record.client_name);
        jb.add_string("cashier_name", record.cashier_name);
        jb.add_string("created_at", record.created_at);

        // ── Items array ──────────────────────────────────────────────────
        jb.start_array("items");
        for (const auto& item : record.items) {
            jb.start_object();
            jb.add_int("product_id", item.product_id);
            jb.add_int("quantity", item.quantity);
            jb.add_double("unit_price", item.unit_price);
            jb.add_double("line_total", item.unit_price * item.quantity);
            jb.end_object();
        }
        jb.end_array();

        jb.end_object();

        return allocate_ffi_string(jb.build());

    } catch (const exception& e) {
        cerr << "[DAL] invoiceRecordToJson error: " << e.what() << endl;
        // Return a valid JSON error object so Dart doesn't crash on null
        return allocate_ffi_string("{\"error\":\"JSON serialization failed\"}");
    }
}

} // namespace data
} // namespace flexistore
