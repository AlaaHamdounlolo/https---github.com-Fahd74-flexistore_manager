#include "product_queries.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include <mysql/jdbc.h>
#include <string>

using namespace std;
using namespace flexistore;

extern "C" {

FLEXISTORE_EXPORT const char* get_all_products(int user_id) {
    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return nullptr;

    try {
        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "SELECT id, barcode, name, category, purchase_price, selling_price, stock_quantity, status "
            "FROM products WHERE status != 'inactive' ORDER BY id DESC"
        ));
        unique_ptr<sql::ResultSet> res(pstmt->executeQuery());
        
        string json = JsonBuilder::result_set_to_json(res.get());
        pool.releaseConnection(std::move(conn));
        
        return allocate_ffi_string(json);
    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return nullptr;
    }
}

FLEXISTORE_EXPORT const char* get_inventory_stats(int user_id) {
    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return nullptr;

    try {
        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "SELECT COUNT(id) AS total_products, "
            "SUM(IF(stock_quantity <= 10, 1, 0)) AS low_stock_items, "
            "SUM(stock_quantity * purchase_price) AS total_value "
            "FROM products WHERE status != 'inactive'"
        ));
        unique_ptr<sql::ResultSet> res(pstmt->executeQuery());
        
        JsonBuilder jb;
        if (res->next()) {
            jb.start_object();
            jb.add_int("totalProducts", res->getInt("total_products"));
            jb.add_int("lowStockItems", res->isNull("low_stock_items") ? 0 : res->getInt("low_stock_items"));
            jb.add_double("totalValue", res->isNull("total_value") ? 0.0 : res->getDouble("total_value"));
            jb.end_object();
        } else {
            jb.start_object();
            jb.add_int("totalProducts", 0);
            jb.add_int("lowStockItems", 0);
            jb.add_double("totalValue", 0.0);
            jb.end_object();
        }
        
        pool.releaseConnection(std::move(conn));
        
        return allocate_ffi_string(jb.build());
    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return nullptr;
    }
}

FLEXISTORE_EXPORT const char* get_filtered_inventory(int user_id, const char* search_query, const char* category) {
    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return allocate_ffi_string("[]");

    try {
        // بناء الاستعلام بناءً على البحث والتصنيف
        string sql = "SELECT id, barcode, name, category, purchase_price, selling_price, stock_quantity, status "
                    "FROM products WHERE status != 'inactive' AND (name LIKE ? OR barcode LIKE ?)";
        
        string cat_str = category ? string(category) : "All Categories";
        if (cat_str != "All Categories") {
            sql += " AND category = ?";
        }
        sql += " ORDER BY id DESC";

        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(sql));
        
        string formatted_query = "%" + (search_query ? string(search_query) : "") + "%";
        pstmt->setString(1, formatted_query);
        pstmt->setString(2, formatted_query);
        
        if (cat_str != "All Categories") {
            pstmt->setString(3, cat_str);
        }

        unique_ptr<sql::ResultSet> res(pstmt->executeQuery());
        
        // تحويل النتائج إلى JSON لإرسالها لـ Flutter
        string json = JsonBuilder::result_set_to_json(res.get());
        pool.releaseConnection(std::move(conn));
        
        return allocate_ffi_string(json);
    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return allocate_ffi_string("[]");
    }
}

FLEXISTORE_EXPORT const char* get_product_by_barcode(int user_id, const char* barcode) {
    if (!barcode || string(barcode).empty()) return nullptr;

    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return nullptr;

    try {
        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "SELECT id, barcode, name, category, purchase_price, selling_price, stock_quantity, status "
            "FROM products WHERE barcode = ? AND status != 'inactive' LIMIT 1"
        ));
        pstmt->setString(1, barcode);
        unique_ptr<sql::ResultSet> res(pstmt->executeQuery());

        if (!res->next()) {
            pool.releaseConnection(std::move(conn));
            return nullptr; // Product not found
        }

        JsonBuilder jb;
        jb.start_object();
        jb.add_int("id", res->getInt("id"));
        jb.add_string("barcode", res->getString("barcode"));
        jb.add_string("name", res->getString("name"));
        jb.add_string("category", res->getString("category"));
        jb.add_double("purchase_price", res->getDouble("purchase_price"));
        jb.add_double("selling_price", res->getDouble("selling_price"));
        jb.add_int("stock_quantity", res->getInt("stock_quantity"));
        jb.add_string("status", res->getString("status"));
        jb.end_object();

        pool.releaseConnection(std::move(conn));
        return allocate_ffi_string(jb.build());
    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return nullptr;
    }
}

FLEXISTORE_EXPORT const char* get_low_stock_products(int user_id, int threshold) {
    if (threshold <= 0) threshold = 10; // Default threshold

    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return allocate_ffi_string("[]");

    try {
        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "SELECT id, barcode, name, category, purchase_price, selling_price, stock_quantity, status "
            "FROM products WHERE status != 'inactive' AND stock_quantity <= ? "
            "ORDER BY stock_quantity ASC"
        ));
        pstmt->setInt(1, threshold);
        unique_ptr<sql::ResultSet> res(pstmt->executeQuery());

        string json = JsonBuilder::result_set_to_json(res.get());
        pool.releaseConnection(std::move(conn));

        return allocate_ffi_string(json);
    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return allocate_ffi_string("[]");
    }
}

} // extern "C"
