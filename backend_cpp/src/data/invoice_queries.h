#ifndef FLEXISTORE_INVOICE_QUERIES_H
#define FLEXISTORE_INVOICE_QUERIES_H

/*******************************************************************************
 * invoice_queries.h — FlexiStore Manager (Data Access Layer)
 *
 * Clean Data Access Layer (DAL) for invoice and stock operations.
 * Separates raw SQL queries from business logic in pos_functions.cpp.
 *
 * All functions operate within a caller-provided sql::Connection so they
 * can participate in external transactions (BEGIN / COMMIT / ROLLBACK).
 *
 * Schema reference: backend_cpp/src/core/db_initializer.cpp
 *   - products      → stock_quantity (INT)
 *   - invoices      → id, client_id, user_id, total_amount, net_amount, payment_type
 *   - invoice_items → id, invoice_id, product_id, quantity, unit_price
 ******************************************************************************/

#include "../core/ffi_types.h"

#include <string>
#include <vector>

// Forward declarations
namespace sql {
    class Connection;
}

namespace flexistore {
namespace data {

// ── Data Structures ──────────────────────────────────────────────────────────

/// Represents a single line-item in a sale or return.
struct InvoiceItem {
    int    product_id;
    int    quantity;
    double unit_price;
};

/// Represents a full invoice with its items (returned by findInvoiceById).
struct InvoiceRecord {
    int         id;
    int         client_id;      // 0 = Guest
    int         user_id;
    double      total_amount;
    double      net_amount;
    std::string payment_type;   // "cash", "installment", "return"
    std::string client_name;    // resolved via JOIN
    std::string cashier_name;   // resolved via JOIN
    std::string created_at;
    std::vector<InvoiceItem> items;
};

// ── Stock Operations ─────────────────────────────────────────────────────────

/**
 * Validates that a product exists, is active, and has sufficient stock.
 *
 * Uses SELECT ... FOR UPDATE to acquire a row-level lock within the
 * caller's transaction, preventing race conditions on concurrent sales.
 *
 * @param conn       Active MySQL connection (must be within a transaction).
 * @param product_id Product to check.
 * @param required   Quantity needed.
 * @return FFI_SUCCESS if stock is sufficient,
 *         FFI_ERROR_INV_PRODUCT_NOT_FOUND if product doesn't exist / inactive,
 *         FFI_ERROR_POS_INSUFFICIENT_STOCK if stock < required.
 */
int validateStock(sql::Connection* conn, int product_id, int required);

/**
 * Decrements or increments the stock quantity for a product.
 *
 * For a sale:   updateStock(conn, productId, -qty)   → decrement
 * For a return: updateStock(conn, productId, +qty)   → increment
 *
 * Does NOT validate availability — call validateStock() first if needed.
 *
 * @param conn       Active MySQL connection (should be in a transaction).
 * @param product_id Product to update.
 * @param delta      Amount to add (negative = decrement, positive = increment).
 * @return FFI_SUCCESS on success, or FFI_ERROR_DB_QUERY on failure.
 */
int updateStock(sql::Connection* conn, int product_id, int delta);

// ── Invoice Operations ───────────────────────────────────────────────────────

/**
 * Saves a complete invoice (header + line items) in a single call.
 *
 * This function does NOT manage transactions — the caller must wrap it
 * in BEGIN/COMMIT/ROLLBACK to guarantee atomicity with stock updates.
 *
 * Steps:
 *   1. INSERT INTO invoices (client_id, user_id, total_amount, net_amount, payment_type)
 *   2. Retrieve LAST_INSERT_ID() as the new invoice_id
 *   3. INSERT INTO invoice_items for each item in the vector
 *
 * @param conn         Active MySQL connection.
 * @param user_id      The cashier (user) processing the sale.
 * @param client_id    Client ID, or 0 for Guest (stored as NULL).
 * @param total_amount Gross total before discount.
 * @param net_amount   Net total after discount.
 * @param payment_type "cash", "installment", or "return".
 * @param items        Vector of line items (product_id, quantity, unit_price).
 * @return The new invoice_id (> 0) on success,
 *         FFI_ERROR_POS_INVOICE_FAILED if the INSERT fails,
 *         FFI_ERROR_DB_QUERY on SQL error.
 */
int saveFullInvoice(
    sql::Connection* conn,
    int user_id,
    int client_id,
    double total_amount,
    double net_amount,
    const std::string& payment_type,
    const std::vector<InvoiceItem>& items
);

/**
 * Fetches a full invoice record (header + items) by invoice ID.
 *
 * Performs two queries:
 *   1. SELECT from invoices JOIN clients JOIN users (header)
 *   2. SELECT from invoice_items JOIN products (line items)
 *
 * Used by the Return feature on the POS screen to display the original
 * transaction before processing a return.
 *
 * @param conn       Active MySQL connection.
 * @param invoice_id The invoice to retrieve.
 * @param[out] record Populated with the invoice data on success.
 * @return FFI_SUCCESS on success,
 *         FFI_ERROR_NOT_FOUND if the invoice doesn't exist,
 *         FFI_ERROR_DB_QUERY on SQL error.
 */
int findInvoiceById(
    sql::Connection* conn,
    int invoice_id,
    InvoiceRecord& record
);

/**
 * Converts an InvoiceRecord to a JSON string for FFI return.
 *
 * Output format:
 * {
 *   "id": 42,
 *   "client_name": "Ahmed",
 *   "cashier_name": "admin",
 *   "total_amount": 150.00,
 *   "net_amount": 140.00,
 *   "payment_type": "cash",
 *   "created_at": "2026-05-11 12:00:00",
 *   "items": [
 *     { "product_id": 5, "product_name": "...", "quantity": 2,
 *       "unit_price": 25.00, "line_total": 50.00 },
 *     ...
 *   ]
 * }
 *
 * Caller must free the returned pointer with free_ffi_string().
 *
 * @param record The invoice record to serialize.
 * @return Heap-allocated JSON C-string.
 */
const char* invoiceRecordToJson(const InvoiceRecord& record);

} // namespace data
} // namespace flexistore

#endif // FLEXISTORE_INVOICE_QUERIES_H
