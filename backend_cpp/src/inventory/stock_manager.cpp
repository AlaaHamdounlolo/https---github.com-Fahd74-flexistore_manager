#include "stock_manager.h"
#include "../core/db_connection_pool.h"
#include "../audit/audit_logger.h"
#include <mysql/jdbc.h>

using namespace std;

namespace flexistore {

int restock_product(int product_id, int qty, int user_id, sql::Connection* conn) {
    if (qty == 0) return FFI_SUCCESS; // Nothing to do

    bool own_conn = false;
    unique_ptr<sql::Connection> local_conn_ptr;
    
    if (!conn) {
        auto& pool = DBConnectionPool::getInstance();
        local_conn_ptr = pool.getConnection();
        if (!local_conn_ptr) return FFI_ERROR_DB_CONNECTION;
        conn = local_conn_ptr.get();
        own_conn = true;
    }

    try {
        // First check if product exists and won't go negative
        unique_ptr<sql::PreparedStatement> check_stmt(conn->prepareStatement(
            "SELECT stock_quantity FROM products WHERE id = ? AND status != 'inactive' FOR UPDATE"
        ));
        check_stmt->setInt(1, product_id);
        unique_ptr<sql::ResultSet> res(check_stmt->executeQuery());
        
        if (!res->next()) {
            if (own_conn) DBConnectionPool::getInstance().releaseConnection(std::move(local_conn_ptr));
            return FFI_ERROR_INV_PRODUCT_NOT_FOUND;
        }
        
        int current_stock = res->getInt("stock_quantity");
        if (current_stock + qty < 0) {
            if (own_conn) DBConnectionPool::getInstance().releaseConnection(std::move(local_conn_ptr));
            return FFI_ERROR_INV_INSUFFICIENT_STOCK;
        }

        unique_ptr<sql::PreparedStatement> pstmt(conn->prepareStatement(
            "UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?"
        ));
        pstmt->setInt(1, qty);
        pstmt->setInt(2, product_id);
        pstmt->executeUpdate();

        // Log the change
        const char* action = (qty > 0) ? "RESTOCK" : "SALE";
        log_inventory_change(product_id, user_id, action, qty);

        if (own_conn) DBConnectionPool::getInstance().releaseConnection(std::move(local_conn_ptr));
        return FFI_SUCCESS;

    } catch (sql::SQLException&) {
        if (own_conn) DBConnectionPool::getInstance().releaseConnection(std::move(local_conn_ptr));
        return FFI_ERROR_DB_QUERY;
    }
}

} // namespace flexistore
