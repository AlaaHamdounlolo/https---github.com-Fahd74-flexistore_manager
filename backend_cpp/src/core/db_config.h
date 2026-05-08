#ifndef FLEXISTORE_DB_CONFIG_H
#define FLEXISTORE_DB_CONFIG_H

#include <string>
using namespace std;
/*******************************************************************************
 * db_config.h — FlexiStore Manager
 *
 * MySQL connection settings used by the Connection Pool.
 * 
 * DEPLOYMENT NOTE:
 *   In production, these values should be read from an external config file
 *   or environment variables. For now they are compile-time defaults suitable
 *   for the development environment.
 ******************************************************************************/

namespace flexistore {
namespace config {

    // ── Connection Parameters ────────────────────────────────────────────────
    inline const string DB_HOST     = "127.0.0.1";
    inline const string DB_USER     = "root";
    inline const string DB_PASSWORD = "1234";             // Set your MySQL root password
    inline const string DB_NAME     = "flexistore";
    inline const unsigned int DB_PORT    = 3306;

    // ── Connection Pool Tuning ───────────────────────────────────────────────
    inline const int POOL_MIN_SIZE       = 2;   // Connections created at startup
    inline const int POOL_MAX_SIZE       = 10;  // Hard ceiling for concurrent connections

    // ── MySQL Connector URI (tcp://host:port) ────────────────────────────────
    inline string getConnectionUri() {
        return "tcp://" + DB_HOST + ":" + to_string(DB_PORT);
    }

} // namespace config
} // namespace flexistore

#endif // FLEXISTORE_DB_CONFIG_H
