#include "client_functions.h"
#include "../core/db_connection_pool.h"
#include "../core/json_builder.h"
#include <iostream>
#include <memory>
#include <string>

using namespace flexistore;

extern "C" {
    FLEXISTORE_EXPORT const char* get_all_clients(int user_id) {
        JsonBuilder json;
        try {
            auto conn = DBConnectionPool::getInstance().getConnection();
            if (!conn) {
                return allocate_ffi_string("{\"error\": \"Database connection failed\"}");
            }
            
            struct ConnGuard {
                DBConnectionPool& p; std::unique_ptr<sql::Connection> c;
                ~ConnGuard() { if (c) p.releaseConnection(std::move(c)); }
            } guard{DBConnectionPool::getInstance(), std::move(conn)};

            std::unique_ptr<sql::Statement> stmt(guard.c->createStatement());
            // Fetch clients and calculate their total purchases (invoices) and pending debt (total_debt)
            std::unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT c.id, c.name, c.phone, c.email, c.address, c.total_debt, "
                "COALESCE(SUM(i.total_amount), 0) as total_purchases, "
                "(SELECT COUNT(*) FROM installments inst WHERE inst.client_id = c.id AND inst.status = 'active') as active_installments "
                "FROM clients c "
                "LEFT JOIN invoices i ON c.id = i.client_id "
                "GROUP BY c.id, c.name, c.phone, c.email, c.address, c.total_debt "
                "ORDER BY c.name ASC"
            ));

            json.start_array();
            while (rs->next()) {
                json.start_object();
                json.add_int("id", rs->getInt("id"));
                json.add_string("name", rs->getString("name").c_str());
                json.add_string("phone", rs->getString("phone").c_str());
                json.add_string("email", rs->getString("email").c_str());
                json.add_string("address", rs->getString("address").c_str());
                
                double total_debt = rs->getDouble("total_debt");
                json.add_double("total_debt", total_debt);
                json.add_double("total_purchases", rs->getDouble("total_purchases"));
                json.add_int("active_installments", rs->getInt("active_installments"));
                
                std::string status = "Active";
                if (total_debt > 0) status = "Has Debt";
                json.add_string("status", status.c_str());
                
                json.end_object();
            }
            json.end_array();

            return allocate_ffi_string(json.build());
            
        } catch (const sql::SQLException& e) {
            std::cerr << "[Clients] SQLException in get_all_clients: " << e.what() << std::endl;
            
            // Escape quotes for valid JSON
            std::string err_msg = std::string(e.what());
            std::string safe_err;
            for (char c : err_msg) {
                if (c == '"') safe_err += "\\\"";
                else if (c == '\\') safe_err += "\\\\";
                else safe_err += c;
            }
            return allocate_ffi_string("{\"error\": \"" + safe_err + "\"}");
        }
    }
}