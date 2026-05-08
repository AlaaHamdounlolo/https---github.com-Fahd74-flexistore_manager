#include "client_functions.h"
#include "../core/db_connection_pool.h"
#include <iostream>
#include <memory>

using namespace flexistore;

extern "C" {

    int add_client(int user_id, 
                const char* name, 
                const char* phone, 
                const char* email, 
                const char* address, 
                const char* notes) {
        
        if (name == nullptr || phone == nullptr || name[0] == '\0' || phone[0] == '\0') {
            return FFI_ERROR_INVALID_INPUT;
        }

        try {
            auto conn = DBConnectionPool::getInstance().getConnection();
            if (!conn) return FFI_ERROR_DB_CONNECTION;
            
            struct ConnGuard {
                DBConnectionPool& p; std::unique_ptr<sql::Connection> c;
                ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
            } guard{DBConnectionPool::getInstance(), std::move(conn)};

            std::unique_ptr<sql::PreparedStatement> pstmt(guard.c->prepareStatement(
                "INSERT INTO clients (name, phone, email, address, notes) VALUES (?, ?, ?, ?, ?)"
            ));
            
            pstmt->setString(1, name);
            pstmt->setString(2, phone);
            pstmt->setString(3, email ? email : "");
            pstmt->setString(4, address ? address : "");
            pstmt->setString(5, notes ? notes : "");
            
            pstmt->executeUpdate();
            return FFI_SUCCESS; 
        } catch (const sql::SQLException& e) {
            std::cerr << "[Clients] SQLException in add_client: " << e.what() << std::endl;
            // Handle duplicate phone number
            if (e.getErrorCode() == 1062) return FFI_ERROR_CLI_PHONE_EXISTS;
            return FFI_ERROR_DB_QUERY;
        }
    }

    int update_client(int user_id, 
                    int client_id, 
                    const char* name, 
                    const char* phone,
                    const char* email,
                    const char* address,
                    const char* notes) {
        
        if (client_id <= 0 || name == nullptr || phone == nullptr || name[0] == '\0' || phone[0] == '\0') {
            return FFI_ERROR_INVALID_INPUT;
        }

        try {
            auto conn = DBConnectionPool::getInstance().getConnection();
            if (!conn) return FFI_ERROR_DB_CONNECTION;
            
            struct ConnGuard {
                DBConnectionPool& p; std::unique_ptr<sql::Connection> c;
                ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
            } guard{DBConnectionPool::getInstance(), std::move(conn)};

            std::unique_ptr<sql::PreparedStatement> pstmt(guard.c->prepareStatement(
                "UPDATE clients SET name = ?, phone = ?, email = ?, address = ?, notes = ? WHERE id = ?"
            ));
            
            pstmt->setString(1, name);
            pstmt->setString(2, phone);
            pstmt->setString(3, email ? email : "");
            pstmt->setString(4, address ? address : "");
            pstmt->setString(5, notes ? notes : "");
            pstmt->setInt(6, client_id);
            
            int rows = pstmt->executeUpdate();
            if (rows == 0) return FFI_ERROR_NOT_FOUND;
            
            return FFI_SUCCESS;
        } catch (const sql::SQLException& e) {
            std::cerr << "[Clients] SQLException in update_client: " << e.what() << std::endl;
            if (e.getErrorCode() == 1062) return FFI_ERROR_CLI_PHONE_EXISTS;
            return FFI_ERROR_DB_QUERY;
        }
    }

    int delete_client(int user_id, int client_id) {
        if (client_id <= 0) return FFI_ERROR_INVALID_INPUT;

        try {
            auto conn = DBConnectionPool::getInstance().getConnection();
            if (!conn) return FFI_ERROR_DB_CONNECTION;
            
            struct ConnGuard {
                DBConnectionPool& p; std::unique_ptr<sql::Connection> c;
                ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
            } guard{DBConnectionPool::getInstance(), std::move(conn)};

            // First check if client has debt
            std::unique_ptr<sql::PreparedStatement> check_stmt(guard.c->prepareStatement(
                "SELECT total_debt FROM clients WHERE id = ?"
            ));
            check_stmt->setInt(1, client_id);
            std::unique_ptr<sql::ResultSet> rs(check_stmt->executeQuery());
            
            if (rs->next()) {
                double debt = rs->getDouble("total_debt");
                if (debt > 0) return FFI_ERROR_CLI_HAS_DEBT; // Cannot delete client with debt
            } else {
                return FFI_ERROR_NOT_FOUND;
            }

            std::unique_ptr<sql::PreparedStatement> delete_stmt(guard.c->prepareStatement(
                "DELETE FROM clients WHERE id = ?"
            ));
            delete_stmt->setInt(1, client_id);
            delete_stmt->executeUpdate();
            
            return FFI_SUCCESS;
        } catch (const sql::SQLException& e) {
            std::cerr << "[Clients] SQLException in delete_client: " << e.what() << std::endl;
            return FFI_ERROR_DB_QUERY;
        }
    }
}