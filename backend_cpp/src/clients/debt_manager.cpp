#include "debt_manager.h"
#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <memory>
#include <iostream>

namespace flexistore {

    bool update_client_debt(sql::Connection* conn, int client_id, double amount_change) {
        if (!conn) return false;
        
        try {
            // First check the current debt with row locking (FOR UPDATE)
            // This prevents race conditions when multiple transactions try to update debt
            std::unique_ptr<sql::PreparedStatement> lock_stmt(conn->prepareStatement(
                "SELECT total_debt FROM clients WHERE id = ? FOR UPDATE"
            ));
            lock_stmt->setInt(1, client_id);
            std::unique_ptr<sql::ResultSet> rs(lock_stmt->executeQuery());
            
            if (!rs->next()) {
                std::cerr << "[DebtManager] Client " << client_id << " not found." << std::endl;
                return false;
            }
            
            double current_debt = rs->getDouble("total_debt");
            double new_debt = current_debt + amount_change;
            
            // Prevent negative debt (due to precision issues, we use a small epsilon)
            if (new_debt < -0.01) {
                std::cerr << "[DebtManager] Invalid debt update. Client " << client_id 
                        << " would have negative debt: " << new_debt << std::endl;
                return false;
            }
            
            // If it's slightly negative but practically zero, snap to 0
            if (new_debt < 0) new_debt = 0.0;
            
            std::unique_ptr<sql::PreparedStatement> update_stmt(conn->prepareStatement(
                "UPDATE clients SET total_debt = ? WHERE id = ?"
            ));
            update_stmt->setDouble(1, new_debt);
            update_stmt->setInt(2, client_id);
            update_stmt->executeUpdate();
            
            return true;
        } catch (const sql::SQLException& e) {
            std::cerr << "[DebtManager] SQL Exception: " << e.what() << std::endl;
            return false;
        }
    }

}
