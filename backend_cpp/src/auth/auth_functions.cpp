#include "auth_functions.h"
#include "core/db_connection_pool.h"
#include "core/session_manager.h"

#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <cppconn/exception.h>

#include <memory>
#include <iostream>

using namespace flexistore;

extern "C" {

FLEXISTORE_EXPORT int login(const char* username, const char* password_hash) {
    if (!username || !password_hash) {
        return FFI_ERROR_INVALID_INPUT;
    }

    try {
        auto& pool = DBConnectionPool::getInstance();
        auto conn = pool.getConnection();

        if (!conn) {
            return FFI_ERROR_DB_CONNECTION;
        }

        // RAII wrapper to ensure connection is safely returned to the pool
        struct ConnectionReleaser {
            DBConnectionPool& p;
            std::unique_ptr<sql::Connection> c;
            ~ConnectionReleaser() {
                if (c) {
                    p.releaseConnection(std::move(c));
                }
            }
        } releaser{pool, std::move(conn)};

        std::unique_ptr<sql::PreparedStatement> pstmt(
            releaser.c->prepareStatement("SELECT id, name, role FROM users WHERE username = ? AND password_hash = ?")
        );

        pstmt->setString(1, username);
        pstmt->setString(2, password_hash);

        std::unique_ptr<sql::ResultSet> res(pstmt->executeQuery());

        if (res->next()) {
            int id = res->getInt("id");
            std::string name = res->getString("name");
            std::string role = res->getString("role");
            
            SessionManager::get_instance().set_session(id, role, name);
            return FFI_SUCCESS; // Connection automatically returned to pool by releaser
        } else {
            return FFI_ERROR_AUTH_INVALID_CREDS; // Connection automatically returned to pool by releaser
        }

    } catch (const sql::SQLException& e) {
        std::cerr << "[Auth] SQLException in login: " << e.what() 
                << " (MySQL error code: " << e.getErrorCode() << ")" << std::endl;
        return FFI_ERROR_DB_QUERY;
    } catch (const std::exception& e) {
        std::cerr << "[Auth] std::exception in login: " << e.what() << std::endl;
        return FFI_ERROR_UNKNOWN;
    } catch (...) {
        std::cerr << "[Auth] Unknown error in login." << std::endl;
        return FFI_ERROR_UNKNOWN;
    }
}

FLEXISTORE_EXPORT int logout() {
    try {
        SessionManager::get_instance().clear_session();
        return FFI_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "[Auth] std::exception in logout: " << e.what() << std::endl;
        return FFI_ERROR_UNKNOWN;
    } catch (...) {
        std::cerr << "[Auth] Unknown error in logout." << std::endl;
        return FFI_ERROR_UNKNOWN;
    }
}

}
