#include "pos_functions.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include "../core/session_manager.h"
#include "../inventory/stock_manager.h"
#include "../audit/audit_logger.h"

#include <mysql/jdbc.h>
#include <string>
#include <vector>
#include <sstream>
#include <mutex>
#include <iostream>
#include <cstring>
#include <cstdlib>

using namespace std;

namespace {

// ── Minimal JSON parsing helpers (no external dep) ───────────────────────────

struct CartItemData {
    int product_id;
    int quantity;
    double unit_price;
};

/// Skips whitespace in a C-string from position `pos`.
void skip_ws(const char* s, size_t& pos) {
    while (s[pos] && (s[pos] == ' ' || s[pos] == '\t' ||
                      s[pos] == '\n' || s[pos] == '\r'))
        ++pos;
}

/// Parses a JSON number (int or double) from position `pos`.
double parse_number(const char* s, size_t& pos) {
    size_t start = pos;
    if (s[pos] == '-') ++pos;
    while (s[pos] >= '0' && s[pos] <= '9') ++pos;
    if (s[pos] == '.') {
        ++pos;
        while (s[pos] >= '0' && s[pos] <= '9') ++pos;
    }
    string num_str(s + start, pos - start);
    return std::stod(num_str);
}

/// Parses a JSON string (expects opening quote at pos).
string parse_string(const char* s, size_t& pos) {
    if (s[pos] != '"') return "";
    ++pos; // skip opening "
    string result;
    while (s[pos] && s[pos] != '"') {
        if (s[pos] == '\\' && s[pos + 1]) {
            ++pos;
        }
        result += s[pos++];
    }
    if (s[pos] == '"') ++pos; // skip closing "
    return result;
}

/// Parses a JSON array of cart items.
/// Expected format: [{"product_id":1,"quantity":2,"unit_price":10.5}, ...]
vector<CartItemData> parse_items_json(const char* json) {
    vector<CartItemData> items;
    if (!json) return items;

    size_t pos = 0;
    skip_ws(json, pos);
    if (json[pos] != '[') return items;
    ++pos; // skip '['

    while (json[pos]) {
        skip_ws(json, pos);
        if (json[pos] == ']') break;
        if (json[pos] == ',') { ++pos; continue; }
        if (json[pos] != '{') break;
        ++pos; // skip '{'

        CartItemData item = {0, 0, 0.0};
        while (json[pos] && json[pos] != '}') {
            skip_ws(json, pos);
            if (json[pos] == ',') { ++pos; continue; }
            string key = parse_string(json, pos);
            skip_ws(json, pos);
            if (json[pos] == ':') ++pos;
            skip_ws(json, pos);

            if (key == "product_id") {
                item.product_id = static_cast<int>(parse_number(json, pos));
            } else if (key == "quantity") {
                item.quantity = static_cast<int>(parse_number(json, pos));
            } else if (key == "unit_price") {
                item.unit_price = parse_number(json, pos);
            } else {
                // skip unknown value (number or string)
                if (json[pos] == '"') parse_string(json, pos);
                else parse_number(json, pos);
            }
        }
        if (json[pos] == '}') ++pos;
        if (item.product_id > 0 && item.quantity > 0) {
            items.push_back(item);
        }
    }
    return items;
}

std::mutex pos_mutex;

// RAII guard for db connection
struct ConnGuard {
    flexistore::DBConnectionPool& p;
    unique_ptr<sql::Connection> c;
    ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
};

} // anonymous namespace


extern "C" {

// ═══════════════════════════════════════════════════════════════════════════════
// pos_validate_stock
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT int pos_validate_stock(const char* items_json) {
    if (!items_json) return FFI_ERROR_INVALID_INPUT;

    auto items = parse_items_json(items_json);
    if (items.empty()) return FFI_ERROR_POS_EMPTY_CART;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    try {
        for (auto& ci : items) {
            unique_ptr<sql::PreparedStatement> stmt(guard.c->prepareStatement(
                "SELECT stock_quantity FROM products WHERE id = ? AND status = 'active'"
            ));
            stmt->setInt(1, ci.product_id);
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery());

            if (!rs->next()) return FFI_ERROR_INV_PRODUCT_NOT_FOUND;

            int stock = rs->getInt("stock_quantity");
            if (stock < ci.quantity) return FFI_ERROR_POS_INSUFFICIENT_STOCK;
        }
        return FFI_SUCCESS;
    } catch (sql::SQLException&) {
        return FFI_ERROR_DB_QUERY;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// pos_process_sale — atomic transaction
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT int pos_process_sale(
    int user_id,
    int client_id,
    const char* items_json,
    double total_amount,
    double net_amount,
    const char* payment_type
) {
    std::lock_guard<std::mutex> lock(pos_mutex);

    if (!items_json || !payment_type) return FFI_ERROR_INVALID_INPUT;

    auto items = parse_items_json(items_json);
    if (items.empty()) return FFI_ERROR_POS_EMPTY_CART;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    sql::Connection* conn = guard.c.get();

    try {
        // ── BEGIN TRANSACTION ─────────────────────────────────────────────
        conn->setAutoCommit(false);

        // ── Step 1: Validate stock with row locks ─────────────────────────
        for (auto& ci : items) {
            unique_ptr<sql::PreparedStatement> stmt(conn->prepareStatement(
                "SELECT stock_quantity FROM products "
                "WHERE id = ? AND status = 'active' FOR UPDATE"
            ));
            stmt->setInt(1, ci.product_id);
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery());

            if (!rs->next()) {
                conn->rollback();
                conn->setAutoCommit(true);
                return FFI_ERROR_INV_PRODUCT_NOT_FOUND;
            }

            int current_stock = rs->getInt("stock_quantity");
            if (current_stock < ci.quantity) {
                conn->rollback();
                conn->setAutoCommit(true);
                return FFI_ERROR_POS_INSUFFICIENT_STOCK;
            }
        }

        // ── Step 2: Create invoice ────────────────────────────────────────
        unique_ptr<sql::PreparedStatement> inv_stmt(conn->prepareStatement(
            "INSERT INTO invoices (client_id, user_id, total_amount, net_amount, payment_type) "
            "VALUES (?, ?, ?, ?, ?)"
        ));

        if (client_id > 0) {
            inv_stmt->setInt(1, client_id);
        } else {
            inv_stmt->setNull(1, sql::DataType::INTEGER);
        }
        inv_stmt->setInt(2, user_id);
        inv_stmt->setDouble(3, total_amount);
        inv_stmt->setDouble(4, net_amount);
        inv_stmt->setString(5, payment_type);
        inv_stmt->executeUpdate();

        // Get the generated invoice_id
        unique_ptr<sql::Statement> id_stmt(conn->createStatement());
        unique_ptr<sql::ResultSet> id_rs(id_stmt->executeQuery("SELECT LAST_INSERT_ID() AS id"));
        int invoice_id = 0;
        if (id_rs->next()) {
            invoice_id = id_rs->getInt("id");
        }
        if (invoice_id <= 0) {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_POS_INVOICE_FAILED;
        }

        // ── Step 3: Insert invoice_items + deduct stock ───────────────────
        for (auto& ci : items) {
            // Insert item row
            unique_ptr<sql::PreparedStatement> item_stmt(conn->prepareStatement(
                "INSERT INTO invoice_items (invoice_id, product_id, quantity, unit_price) "
                "VALUES (?, ?, ?, ?)"
            ));
            item_stmt->setInt(1, invoice_id);
            item_stmt->setInt(2, ci.product_id);
            item_stmt->setInt(3, ci.quantity);
            item_stmt->setDouble(4, ci.unit_price);
            item_stmt->executeUpdate();

            // Deduct stock using Team 2's stock_manager (pass conn for transactional safety)
            int stock_result = flexistore::restock_product(
                ci.product_id, -ci.quantity, user_id, conn
            );
            if (stock_result != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return stock_result;
            }
        }

        // ── Step 4: COMMIT ────────────────────────────────────────────────
        conn->commit();
        conn->setAutoCommit(true);

        // ── Step 5: Audit logging (outside transaction — non-critical) ────
        string action_type = string("POS_") + payment_type + "_SALE";
        // Convert to uppercase
        for (auto& ch : action_type) ch = static_cast<char>(toupper(ch));

        log_transaction(user_id, action_type.c_str(), net_amount);

        // Return invoice_id as success code (always > 0)
        return invoice_id;

    } catch (sql::SQLException& e) {
        std::cerr << "[POS] SQLException in pos_process_sale: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_DB_QUERY;
    } catch (std::exception& e) {
        std::cerr << "[POS] Exception in pos_process_sale: " << e.what() << std::endl;
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_UNKNOWN;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// pos_get_invoice — retrieve invoice + items as JSON
// ═══════════════════════════════════════════════════════════════════════════════

FLEXISTORE_EXPORT const char* pos_get_invoice(int invoice_id) {
    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) {
        return flexistore::allocate_ffi_string("{\"error\":\"DB Connection Failed\"}");
    }

    try {
        sql::Connection* conn = guard.c.get();

        // ── Fetch invoice header ──────────────────────────────────────────
        unique_ptr<sql::PreparedStatement> inv_stmt(conn->prepareStatement(
            "SELECT i.id, i.total_amount, i.net_amount, i.payment_type, "
            "       CAST(i.created_at AS CHAR) AS created_at, "
            "       COALESCE(c.name, 'Guest') AS client_name, "
            "       u.name AS cashier_name "
            "FROM invoices i "
            "LEFT JOIN clients c ON i.client_id = c.id "
            "JOIN users u ON i.user_id = u.id "
            "WHERE i.id = ?"
        ));
        inv_stmt->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> inv_rs(inv_stmt->executeQuery());

        if (!inv_rs->next()) {
            return flexistore::allocate_ffi_string("{\"error\":\"Invoice not found\"}");
        }

        // ── Build invoice JSON ────────────────────────────────────────────
        flexistore::JsonBuilder builder;
        builder.start_object();
        builder.add_int("id", inv_rs->getInt("id"));
        builder.add_string("client_name", inv_rs->getString("client_name"));
        builder.add_string("cashier_name", inv_rs->getString("cashier_name"));

        // Parse amounts safely from string to avoid DECIMAL heap issues
        string total_str = inv_rs->getString("total_amount");
        string net_str = inv_rs->getString("net_amount");
        try {
            builder.add_double("total_amount", std::stod(total_str));
        } catch (...) {
            builder.add_double("total_amount", 0.0);
        }
        try {
            builder.add_double("net_amount", std::stod(net_str));
        } catch (...) {
            builder.add_double("net_amount", 0.0);
        }

        builder.add_string("payment_type", inv_rs->getString("payment_type"));
        builder.add_string("created_at", inv_rs->getString("created_at"));

        // ── Fetch invoice items ───────────────────────────────────────────
        unique_ptr<sql::PreparedStatement> items_stmt(conn->prepareStatement(
            "SELECT p.name AS product_name, ii.quantity, "
            "       CAST(ii.unit_price AS CHAR) AS unit_price "
            "FROM invoice_items ii "
            "JOIN products p ON ii.product_id = p.id "
            "WHERE ii.invoice_id = ? "
            "ORDER BY ii.id"
        ));
        items_stmt->setInt(1, invoice_id);
        unique_ptr<sql::ResultSet> items_rs(items_stmt->executeQuery());

        builder.start_array("items");
        while (items_rs->next()) {
            builder.start_object();
            builder.add_string("product_name", items_rs->getString("product_name"));
            builder.add_int("quantity", items_rs->getInt("quantity"));

            string price_str = items_rs->getString("unit_price");
            double price = 0.0;
            try { price = std::stod(price_str); } catch (...) {}
            builder.add_double("unit_price", price);
            builder.add_double("line_total", price * items_rs->getInt("quantity"));

            builder.end_object();
        }
        builder.end_array();

        builder.end_object();
        return flexistore::allocate_ffi_string(builder.build());

    } catch (sql::SQLException& e) {
        string err = string("{\"error\":\"") + e.what() + "\"}";
        return flexistore::allocate_ffi_string(err);
    } catch (std::exception& e) {
        string err = string("{\"error\":\"") + e.what() + "\"}";
        return flexistore::allocate_ffi_string(err);
    }
}

} // extern "C"
