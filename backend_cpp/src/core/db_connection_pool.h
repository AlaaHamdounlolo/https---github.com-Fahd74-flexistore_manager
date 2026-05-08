#ifndef FLEXISTORE_DB_CONNECTION_POOL_H
#define FLEXISTORE_DB_CONNECTION_POOL_H

#include <memory>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <string>

// MySQL Connector/C++ headers (JDBC-style API)
#include <mysql/jdbc.h>
using namespace std;
/*******************************************************************************
 * db_connection_pool.h — FlexiStore Manager
 *
 * Thread-safe Singleton Connection Pool for MySQL Connector/C++.
 *
 * USAGE BY ALL TEAMS:
 *   auto& pool = DBConnectionPool::getInstance();
 *   auto  conn = pool.getConnection();   // blocks if pool exhausted
 *   // ... use conn->prepareStatement(...) etc. ...
 *   pool.releaseConnection(std::move(conn));
 *
 * The pool lazily grows up to POOL_MAX_SIZE. Connections are validated on
 * checkout; dead connections are silently replaced.
 ******************************************************************************/

namespace flexistore {

class DBConnectionPool {
public:
    // ── Singleton Access ─────────────────────────────────────────────────────
    static DBConnectionPool& getInstance();

    // Non-copyable, non-movable
    DBConnectionPool(const DBConnectionPool&)            = delete;
    DBConnectionPool& operator=(const DBConnectionPool&) = delete;
    DBConnectionPool(DBConnectionPool&&)                 = delete;
    DBConnectionPool& operator=(DBConnectionPool&&)      = delete;

    // ── Public API ───────────────────────────────────────────────────────────

    /**
     * Acquire a connection from the pool.
     * Blocks if all connections are currently in use and the pool is at max.
     * Returns a unique_ptr<Connection> — caller MUST return it via releaseConnection().
     */
    unique_ptr<sql::Connection> getConnection();

    /**
     * Return a connection back to the pool.
     * If the connection is invalid (closed/broken), it is discarded and the
     * pool size is decremented so a new one can be created later.
     */
    void releaseConnection(unique_ptr<sql::Connection> conn);

    /**
     * Gracefully drain and close all pooled connections.
     * Called during application shutdown.
     */
    void shutdown();

    /**
     * Returns the number of connections currently idle in the pool.
     * (For diagnostics / testing.)
     */
    int availableConnections() const;

private:
    // ── Private Constructor (Singleton) ──────────────────────────────────────
    DBConnectionPool();
    ~DBConnectionPool();

    // ── Internal Helpers ─────────────────────────────────────────────────────
    unique_ptr<sql::Connection> createConnection();
    bool isConnectionValid(sql::Connection* conn);

    // ── State ────────────────────────────────────────────────────────────────
    sql::Driver*                                   driver_;       // MySQL driver (singleton, not owned)
    queue<unique_ptr<sql::Connection>>   pool_;         // Idle connections
    mutable mutex                             mutex_;        // Guards pool_ and counts
    condition_variable                        cv_;           // Signals when a conn is returned
    int                                            activeCount_;  // Total connections alive (idle + in-use)
    bool                                           shutdownFlag_; // Prevents new checkouts after shutdown
};

} // namespace flexistore

#endif // FLEXISTORE_DB_CONNECTION_POOL_H
