#include "pos_functions.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include "../core/session_manager.h"
#include "../inventory/stock_manager.h"
#include "../audit/audit_logger.h"
#include "../data/invoice_queries.h"

#include <mysql/jdbc.h>
#include <string>
#include <vector>
#include <mutex>
#include <iostream>
#include <cstring>
#include <cstdlib>

using namespace std;
using namespace flexistore::data;

namespace {

// JSON Parsing Helpers
struct CartItemData {
    int product_id;
    int quantity;
    double unit_price;
};

void skip_ws(const char* s, size_t& pos) {
    while (s[pos] && (s[pos] == ' ' || s[pos] == '\t' || s[pos] == '\n' || s[pos] == '\r')) ++pos;
}

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

string parse_string(const char* s, size_t& pos) {
    if (s[pos] != '"') return "";
    ++pos; 
    string result;
    while (s[pos] && s[pos] != '"') {
        if (s[pos] == '\\' && s[pos + 1]) ++pos;
        result += s[pos++];
    }
    if (s[pos] == '"') ++pos; 
    return result;
}

vector<CartItemData> parse_items_json(const char* json) {
    vector<CartItemData> items;
    if (!json) return items;

    size_t pos = 0;
    skip_ws(json, pos);
    if (json[pos] != '[') return items;
    ++pos; 

    while (json[pos]) {
        skip_ws(json, pos);
        if (json[pos] == ']') break;
        if (json[pos] == ',') { ++pos; continue; }
        if (json[pos] != '{') break;
        ++pos; 

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

struct ConnGuard {
    flexistore::DBConnectionPool& p;
    unique_ptr<sql::Connection> c;
    ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
};

} // namespace

extern "C" {

FLEXISTORE_EXPORT int pos_validate_stock(const char* items_json) {
    if (!items_json) return FFI_ERROR_INVALID_INPUT;

    auto items = parse_items_json(items_json);
    if (items.empty()) return FFI_ERROR_POS_EMPTY_CART;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    sql::Connection* conn = guard.c.get();
    
    // We start a transaction so that the locks held by validateStock (SELECT FOR UPDATE)
    // are valid during the checks.
    try {
        conn->setAutoCommit(false);
        for (const auto& ci : items) {
            int status = flexistore::data::validateStock(conn, ci.product_id, ci.quantity);
            if (status != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return status;
            }
        }
        conn->rollback(); // Don't hold locks for pre-flight check
        conn->setAutoCommit(true);
        return FFI_SUCCESS;
    } catch (...) {
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_DB_QUERY;
    }
}

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
        conn->setAutoCommit(false);

        // 1. Validate Stock using DAL
        for (const auto& ci : items) {
            int status = flexistore::data::validateStock(conn, ci.product_id, ci.quantity);
            if (status != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return status;
            }
        }

        // 2. Prepare DAL Invoice Items
        vector<InvoiceItem> dal_items;
        for (const auto& ci : items) {
            dal_items.push_back({ci.product_id, ci.quantity, ci.unit_price});
        }

        // 3. Save Invoice using DAL
        int invoice_id = flexistore::data::saveFullInvoice(
            conn, user_id, client_id, total_amount, net_amount, payment_type, dal_items
        );

        if (invoice_id <= 0) {
            conn->rollback();
            conn->setAutoCommit(true);
            return invoice_id; // returns FFI_ERROR_POS_INVOICE_FAILED
        }

        // 4. Update Stock and Log Inventory Changes
        // restock_product internally calls log_inventory_change
        for (const auto& ci : items) {
            int stock_result = flexistore::restock_product(ci.product_id, -ci.quantity, user_id, conn);
            if (stock_result != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return stock_result;
            }
        }

        // 5. Commit Transaction
        conn->commit();
        conn->setAutoCommit(true);

        // 6. Audit Log Transaction
        string action_type = string("POS_") + payment_type + "_SALE";
        for (auto& ch : action_type) ch = static_cast<char>(toupper(ch));
        log_transaction(user_id, action_type.c_str(), net_amount);

        return invoice_id;

    } catch (...) {
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_UNKNOWN;
    }
}

FLEXISTORE_EXPORT int pos_process_return(
    int user_id,
    int original_invoice_id,
    const char* items_json
) {
    std::lock_guard<std::mutex> lock(pos_mutex);

    if (original_invoice_id <= 0) return FFI_ERROR_INVALID_INPUT;

    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) return FFI_ERROR_DB_CONNECTION;

    sql::Connection* conn = guard.c.get();

    try {
        conn->setAutoCommit(false);

        // 1. Fetch Original Invoice using DAL
        InvoiceRecord orig_invoice;
        int fetch_status = flexistore::data::findInvoiceById(conn, original_invoice_id, orig_invoice);
        if (fetch_status != FFI_SUCCESS) {
            conn->rollback();
            conn->setAutoCommit(true);
            return fetch_status;
        }

        if (orig_invoice.payment_type == "return") {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_RET_ALREADY_RETURNED;
        }

        // 2. Determine Items to Return
        vector<InvoiceItem> return_items;
        if (items_json && strlen(items_json) > 2) {
            auto requested = parse_items_json(items_json);
            for (const auto& req : requested) {
                bool found = false;
                for (const auto& oi : orig_invoice.items) {
                    if (oi.product_id == req.product_id) {
                        if (req.quantity > oi.quantity) {
                            conn->rollback();
                            conn->setAutoCommit(true);
                            return FFI_ERROR_RET_INVALID_QUANTITY;
                        }
                        return_items.push_back({oi.product_id, req.quantity, oi.unit_price});
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    conn->rollback();
                    conn->setAutoCommit(true);
                    return FFI_ERROR_RET_INVOICE_NOT_FOUND;
                }
            }
        } else {
            // Full return
            return_items = orig_invoice.items;
        }

        if (return_items.empty()) {
            conn->rollback();
            conn->setAutoCommit(true);
            return FFI_ERROR_POS_EMPTY_CART;
        }

        // 3. Calculate Return Total
        double return_total = 0.0;
        for (const auto& ri : return_items) {
            return_total += ri.unit_price * ri.quantity;
        }

        // 4. Save Return Invoice using DAL
        int return_invoice_id = flexistore::data::saveFullInvoice(
            conn, user_id, orig_invoice.client_id, -return_total, -return_total, "return", return_items
        );

        if (return_invoice_id <= 0) {
            conn->rollback();
            conn->setAutoCommit(true);
            return return_invoice_id;
        }

        // 5. Restock and Log Inventory Changes
        for (const auto& ri : return_items) {
            int stock_result = flexistore::restock_product(ri.product_id, ri.quantity, user_id, conn);
            if (stock_result != FFI_SUCCESS) {
                conn->rollback();
                conn->setAutoCommit(true);
                return stock_result;
            }
        }

        // 6. Commit Transaction
        conn->commit();
        conn->setAutoCommit(true);

        // 7. Audit Log Transaction
        log_transaction(user_id, "POS_RETURN", return_total);

        return return_invoice_id;

    } catch (...) {
        try { conn->rollback(); conn->setAutoCommit(true); } catch (...) {}
        return FFI_ERROR_UNKNOWN;
    }
}

FLEXISTORE_EXPORT const char* pos_get_invoice(int invoice_id) {
    auto& pool = flexistore::DBConnectionPool::getInstance();
    ConnGuard guard{pool, pool.getConnection()};
    if (!guard.c) {
        return flexistore::allocate_ffi_string("{\"error\":\"DB Connection Failed\"}");
    }

    InvoiceRecord record;
    int status = flexistore::data::findInvoiceById(guard.c.get(), invoice_id, record);
    
    if (status == FFI_ERROR_NOT_FOUND) {
        return flexistore::allocate_ffi_string("{\"error\":\"Invoice not found\"}");
    } else if (status != FFI_SUCCESS) {
        return flexistore::allocate_ffi_string("{\"error\":\"Failed to fetch invoice\"}");
    }

    return flexistore::data::invoiceRecordToJson(record);
}

} // extern "C"
