#include "dashboard_queries.h"
#include "core/db_connection_pool.h"
#include "core/json_builder.h"
#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <memory>
#include <iostream>
#include <string.h>
#include <cmath>
#include <chrono>


using namespace std;
using namespace flexistore;

// Helper: safely parse DECIMAL value fetched as CHAR to avoid
// MySQL Connector heap corruption on Windows Debug builds.
static double safe_decimal(sql::ResultSet* rs, const std::string& col) {
    try {
        std::string val = rs->getString(col);
        return val.empty() ? 0.0 : std::stod(val);
    } catch (...) {
        return 0.0;
    }
}

static int safe_int(sql::ResultSet* rs, const std::string& col) {
    try {
        std::string val = rs->getString(col);
        return val.empty() ? 0 : std::stoi(val);
    } catch (...) {
        return 0;
    }
}

extern "C" {

// Helper to calculate percentage growth
double calc_growth(double current, double previous) {
    if (previous == 0) {
        return current > 0 ? 100.0 : 0.0;
    }
    return ((current - previous) / previous) * 100.0;
}

FLEXISTORE_EXPORT const char* get_dashboard_stats(int user_id) {
    try {
        auto& pool = DBConnectionPool::getInstance();
        auto conn = pool.getConnection();

        if (!conn) {
            return allocate_ffi_string("{\"error\": \"Database connection failed\"}");
        }

        struct ConnectionReleaser {
            DBConnectionPool& p;
            std::unique_ptr<sql::Connection> c;
            ~ConnectionReleaser() {
                if (c) {
                    p.releaseConnection(std::move(c));
                }
            }
        } releaser{pool, std::move(conn)};

        JsonBuilder builder;
        builder.start_object();

        // 1. Revenue & Sales (Today vs Yesterday)
        {
            unique_ptr<sql::Statement> stmt(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT "
                "  CAST(IFNULL(SUM(CASE WHEN DATE(created_at) = CURDATE() THEN net_amount ELSE 0 END), 0) AS CHAR) AS today_rev, "
                "  CAST(IFNULL(SUM(CASE WHEN DATE(created_at) = DATE_SUB(CURDATE(), INTERVAL 1 DAY) THEN net_amount ELSE 0 END), 0) AS CHAR) AS yest_rev, "
                "  CAST(IFNULL(SUM(CASE WHEN DATE(created_at) = CURDATE() THEN 1 ELSE 0 END), 0) AS CHAR) AS today_sales, "
                "  CAST(IFNULL(SUM(CASE WHEN DATE(created_at) = DATE_SUB(CURDATE(), INTERVAL 1 DAY) THEN 1 ELSE 0 END), 0) AS CHAR) AS yest_sales "
                "FROM invoices "
                "WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 1 DAY)"
            ));

            if (rs->next()) {
                double today_rev = safe_decimal(rs.get(), "today_rev");
                double yest_rev = safe_decimal(rs.get(), "yest_rev");
                int today_sales = safe_int(rs.get(), "today_sales");
                int yest_sales = safe_int(rs.get(), "yest_sales");

                builder.add_double("today_revenue", today_rev);
                builder.add_double("revenue_growth", calc_growth(today_rev, yest_rev));
                
                builder.add_int("total_sales_count", today_sales);
                builder.add_double("sales_growth", calc_growth(today_sales, yest_sales));
            } else {
                builder.add_double("today_revenue", 0.0);
                builder.add_double("revenue_growth", 0.0);
                builder.add_int("total_sales_count", 0);
                builder.add_double("sales_growth", 0.0);
            }
        }

        // 2. Active Clients & Growth (This month vs Last month)
        {
            unique_ptr<sql::Statement> stmt(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT "
                "  CAST(COUNT(*) AS CHAR) AS total_clients, "
                "  CAST(IFNULL(SUM(CASE WHEN MONTH(created_at) = MONTH(CURDATE()) AND YEAR(created_at) = YEAR(CURDATE()) THEN 1 ELSE 0 END), 0) AS CHAR) AS clients_this_month, "
                "  CAST(IFNULL(SUM(CASE WHEN MONTH(created_at) = MONTH(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)) AND YEAR(created_at) = YEAR(DATE_SUB(CURDATE(), INTERVAL 1 MONTH)) THEN 1 ELSE 0 END), 0) AS CHAR) AS clients_last_month "
                "FROM clients"
            ));

            if (rs->next()) {
                int total_clients = safe_int(rs.get(), "total_clients");
                int this_m = safe_int(rs.get(), "clients_this_month");
                int last_m = safe_int(rs.get(), "clients_last_month");

                builder.add_int("active_clients_count", total_clients);
                builder.add_double("clients_growth", calc_growth(this_m, last_m));
            } else {
                builder.add_int("active_clients_count", 0);
                builder.add_double("clients_growth", 0.0);
            }
        }

        // 3. Pending Payments (Total Debt from Clients)
        {
            unique_ptr<sql::Statement> stmt(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT CAST(IFNULL(SUM(total_debt), 0) AS CHAR) AS total_pending FROM clients"
            ));

            if (rs->next()) {
                builder.add_double("pending_payments", safe_decimal(rs.get(), "total_pending"));
                builder.add_double("pending_growth", -5.3); // As requested
            } else {
                builder.add_double("pending_payments", 0.0);
                builder.add_double("pending_growth", 0.0);
            }
        }

        // 4. Revenue Chart (Last 7 Days)
        {
            builder.start_array("revenue_chart");
            unique_ptr<sql::Statement> stmt(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT CAST(DATE(created_at) AS CHAR) as day_date, "
                "CAST(IFNULL(SUM(net_amount), 0) AS CHAR) as daily_revenue "
                "FROM invoices "
                "WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY) "
                "GROUP BY day_date "
                "ORDER BY day_date ASC"
            ));

            while (rs->next()) {
                builder.start_object();
                builder.add_string("day", rs->getString("day_date"));
                builder.add_double("amount", safe_decimal(rs.get(), "daily_revenue"));
                builder.end_object();
            }
            builder.end_array();
        }

        // 5. Recent Transactions
        {
            builder.start_array("recent_transactions");
            unique_ptr<sql::Statement> stmt(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT i.id, IFNULL(c.name, 'Unknown Client') AS client_name, "
                "CAST(i.net_amount AS CHAR) AS net_amount, "
                "CAST((SELECT COUNT(*) FROM invoice_items ii WHERE ii.invoice_id = i.id) AS CHAR) AS items_count, "
                "CAST(i.created_at AS CHAR) AS created_at, i.payment_type "
                "FROM invoices i "
                "LEFT JOIN clients c ON i.client_id = c.id "
                "ORDER BY i.created_at DESC LIMIT 4"
            ));

            while (rs->next()) {
                builder.start_object();
                builder.add_int("id", rs->getInt("id"));
                builder.add_string("client_name", rs->getString("client_name"));
                builder.add_double("amount", safe_decimal(rs.get(), "net_amount"));
                builder.add_int("items_count", safe_int(rs.get(), "items_count"));
                builder.add_string("created_at", rs->getString("created_at"));
                
                std::string p_type = rs->getString("payment_type");
                std::string status = (p_type == "cash") ? "completed" : "pending";
                builder.add_string("status", status);
                
                builder.end_object();
            }
            builder.end_array();
        }

        // 6. Low Stock Alerts
        {
            builder.start_array("low_stock_alerts");
            unique_ptr<sql::Statement> stmt(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs(stmt->executeQuery(
                "SELECT name, stock_quantity "
                "FROM products "
                "WHERE stock_quantity < 10 AND status = 'active' "
                "ORDER BY stock_quantity ASC LIMIT 10"
            ));

            while (rs->next()) {
                builder.start_object();
                builder.add_string("name", rs->getString("name"));
                int qty = rs->getInt("stock_quantity");
                builder.add_int("stock_quantity", qty);
                builder.add_string("status", qty < 3 ? "Critical" : "Low Stock");
                builder.end_object();
            }
            builder.end_array();
            
            // Also add low_stock count at root (since dashboard_ffi might still use it)
            // Wait, I am still inside the root object, so I'll add the aggregate later or fetch it again.
            // Let's just do a quick count query for the root `low_stock` property.
            unique_ptr<sql::Statement> stmt_count(releaser.c->createStatement());
            unique_ptr<sql::ResultSet> rs_count(stmt_count->executeQuery(
                "SELECT CAST(COUNT(*) AS CHAR) AS c FROM products WHERE stock_quantity < 10 AND status = 'active'"
            ));
            if (rs_count->next()) {
                builder.add_int("low_stock", safe_int(rs_count.get(), "c"));
            } else {
                builder.add_int("low_stock", 0);
            }
        }

        builder.end_object();
        return allocate_ffi_string(builder.build());

    } catch (const sql::SQLException& e) {
        cerr << "[Dashboard] SQLException: " << e.what() << " (MySQL error code: " << e.getErrorCode() << ")" << endl;
        
        std::string err_msg = std::string(e.what()) + " (Code: " + std::to_string(e.getErrorCode()) + ")";
        
        std::string safe_err;
        for (char c : err_msg) {
            if (c == '"') safe_err += "\\\"";
            else if (c == '\\') safe_err += "\\\\";
            else safe_err += c;
        }

        std::string json_err = "{\"error\": \"" + safe_err + "\"}";
        return allocate_ffi_string(json_err);
    } catch (const std::exception& e) {
        cerr << "[Dashboard] std::exception: " << e.what() << endl;
        return allocate_ffi_string("{\"error\": \"Unknown error occurred\"}");
    } catch (...) {
        return allocate_ffi_string("{\"error\": \"Unknown error occurred\"}");
    }
}

} // extern "C"
