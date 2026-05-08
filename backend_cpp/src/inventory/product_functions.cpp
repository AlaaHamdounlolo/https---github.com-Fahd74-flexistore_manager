#include "product_functions.h"
#include "../core/db_connection_pool.h"
#include "../audit/audit_logger.h"
#include <mysql/jdbc.h>
#include <string>
#include <iostream>

using namespace std;
using namespace flexistore;

extern "C" {

FLEXISTORE_EXPORT int add_product(int user_id, const char* barcode, const char* name, const char* category, double purchase_price, double selling_price, int stock_quantity) {
    if (!barcode || !name || string(barcode).empty() || string(name).empty()) {
        return FFI_ERROR_INVALID_INPUT;
    }
    if (purchase_price <= 0 || selling_price <= 0) {
        return FFI_ERROR_INV_INVALID_PRICE;
    }
    if (stock_quantity < 0) {
        return FFI_ERROR_INV_INVALID_QUANTITY;
    }

    string cat = (category && string(category).length() > 0) ? string(category) : "General";

    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return FFI_ERROR_DB_CONNECTION;

    try {
        // Check for duplicate barcode
        unique_ptr<sql::PreparedStatement> check_stmt(conn->prepareStatement("SELECT id FROM products WHERE barcode = ?"));
        check_stmt->setString(1, barcode);
        unique_ptr<sql::ResultSet> res(check_stmt->executeQuery());
        if (res->next()) {
            pool.releaseConnection(std::move(conn));
            return FFI_ERROR_INV_DUPLICATE_BARCODE;
        }

        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "INSERT INTO products (barcode, name, category, purchase_price, selling_price, stock_quantity, status) "
            "VALUES (?, ?, ?, ?, ?, ?, 'active')"
        ));
        pstmt->setString(1, barcode);
        pstmt->setString(2, name);
        pstmt->setString(3, cat);
        pstmt->setDouble(4, purchase_price);
        pstmt->setDouble(5, selling_price);
        pstmt->setInt(6, stock_quantity);
        pstmt->executeUpdate();

        // Get last insert ID
        unique_ptr<sql::Statement> stmt(conn->createStatement());
        unique_ptr<sql::ResultSet> id_res(stmt->executeQuery("SELECT LAST_INSERT_ID()"));
        int product_id = 0;
        if (id_res->next()) {
            product_id = id_res->getInt(1);
        }

        pool.releaseConnection(std::move(conn));

        if (product_id > 0) {
            log_inventory_change(product_id, user_id, "ADD", stock_quantity);
        }
        
        return FFI_SUCCESS;

    } catch (sql::SQLException& e) {
        std::cout << "[add_product] SQL Error: " << e.what() << " (MySQL error code: " << e.getErrorCode() << ", SQLState: " << e.getSQLState() << ")" << std::endl;
        pool.releaseConnection(std::move(conn));
        return FFI_ERROR_DB_QUERY;
    }
}

FLEXISTORE_EXPORT int update_product(int user_id, int product_id, const char* barcode, const char* name, const char* category, double purchase_price, double selling_price) {
    if (!barcode || !name || string(barcode).empty() || string(name).empty()) {
        return FFI_ERROR_INVALID_INPUT;
    }
    if (purchase_price <= 0 || selling_price <= 0) {
        return FFI_ERROR_INV_INVALID_PRICE;
    }

    string cat = (category && string(category).length() > 0) ? string(category) : "General";

    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return FFI_ERROR_DB_CONNECTION;

    try {
        // Check duplicate barcode for OTHER products
        unique_ptr<sql::PreparedStatement> check_stmt(conn->prepareStatement("SELECT id FROM products WHERE barcode = ? AND id != ?"));
        check_stmt->setString(1, barcode);
        check_stmt->setInt(2, product_id);
        unique_ptr<sql::ResultSet> res(check_stmt->executeQuery());
        if (res->next()) {
            pool.releaseConnection(std::move(conn));
            return FFI_ERROR_INV_DUPLICATE_BARCODE;
        }

        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "UPDATE products SET barcode = ?, name = ?, category = ?, purchase_price = ?, selling_price = ? "
            "WHERE id = ? AND status != 'inactive'"
        ));
        pstmt->setString(1, barcode);
        pstmt->setString(2, name);
        pstmt->setString(3, cat);
        pstmt->setDouble(4, purchase_price);
        pstmt->setDouble(5, selling_price);
        pstmt->setInt(6, product_id);
        
        int rows = pstmt->executeUpdate();
        pool.releaseConnection(std::move(conn));

        if (rows == 0) {
            return FFI_ERROR_INV_PRODUCT_NOT_FOUND;
        }

        log_inventory_change(product_id, user_id, "UPDATE", 0);
        return FFI_SUCCESS;

    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return FFI_ERROR_DB_QUERY;
    }
}

FLEXISTORE_EXPORT int soft_delete_product(int user_id, int product_id) {
    auto& pool = DBConnectionPool::getInstance();
    auto conn = pool.getConnection();
    if (!conn) return FFI_ERROR_DB_CONNECTION;

    try {
        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "UPDATE products SET status = 'inactive' WHERE id = ?"
        ));
        pstmt->setInt(1, product_id);
        int rows = pstmt->executeUpdate();
        pool.releaseConnection(std::move(conn));

        if (rows == 0) {
            return FFI_ERROR_INV_PRODUCT_NOT_FOUND;
        }

        log_inventory_change(product_id, user_id, "DELETE", 0);
        return FFI_SUCCESS;

    } catch (sql::SQLException&) {
        pool.releaseConnection(std::move(conn));
        return FFI_ERROR_DB_QUERY;
    }
}

} // extern "C"
