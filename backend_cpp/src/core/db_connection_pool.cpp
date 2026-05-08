/*******************************************************************************
 * db_connection_pool.cpp — FlexiStore Manager
 *
 * Thread-safe Singleton Connection Pool implementation.
 *
 * Behaviour:
 *   - On first call to getInstance(), the pool creates POOL_MIN_SIZE connections.
 *   - getConnection() returns an idle connection or creates a new one if below
 *     POOL_MAX_SIZE. If at max, it blocks until one is released.
 *   - Connections are validated (isValid) before being handed out.  Dead ones
 *     are silently replaced.
 *   - shutdown() drains the pool and prevents further checkouts.
 ******************************************************************************/

#include "db_connection_pool.h"
#include "db_config.h"

#include <iostream>
#include <stdexcept>
using namespace std;
namespace flexistore {

// ═════════════════════════════════════════════════════════════════════════════
// Singleton
// ═════════════════════════════════════════════════════════════════════════════
DBConnectionPool& DBConnectionPool::getInstance() {
    static DBConnectionPool instance;
    return instance;
}

// ═════════════════════════════════════════════════════════════════════════════
// Constructor — seeds the pool with POOL_MIN_SIZE connections
// ═════════════════════════════════════════════════════════════════════════════
DBConnectionPool::DBConnectionPool()
    : driver_(nullptr),
    activeCount_(0),
    shutdownFlag_(false)
{
    try {
        driver_ = sql::mysql::get_mysql_driver_instance();

        // Pre-create the minimum number of connections
        for (int i = 0; i < config::POOL_MIN_SIZE; ++i) {
            auto conn = createConnection();
            if (conn) {
                pool_.push(move(conn));
                ++activeCount_;
            }
        }

        cout << "[DBConnectionPool] Initialized with "
                << activeCount_ << " connections." << endl;
    }
    catch (const sql::SQLException& e) {
        cerr << "[DBConnectionPool] FATAL — Failed to initialize: "
                << e.what() << " (MySQL error code: " << e.getErrorCode()
                << ")" << endl;
        throw;
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// Destructor
// ═════════════════════════════════════════════════════════════════════════════
DBConnectionPool::~DBConnectionPool() {
    shutdown();
}

// ═════════════════════════════════════════════════════════════════════════════
// createConnection — builds a new MySQL connection using db_config settings
// ═════════════════════════════════════════════════════════════════════════════
unique_ptr<sql::Connection> DBConnectionPool::createConnection() {
    try {
        sql::ConnectOptionsMap opts;
        opts["hostName"] = config::getConnectionUri();
        opts["userName"] = config::DB_USER;
        opts["password"] = config::DB_PASSWORD;
        opts["OPT_RECONNECT"] = true;
        opts["OPT_CHARSET_NAME"] = string("utf8mb4");

        unique_ptr<sql::Connection> conn(driver_->connect(opts));

        // Switch to the flexistore database (may not exist yet during init)
        try {
            conn->setSchema(config::DB_NAME);
        } catch (...) {
            // Silently ignore — db_initializer will create it first
        }

        conn->setAutoCommit(true);
        return conn;
    }
    catch (const sql::SQLException& e) {
        cerr << "[DBConnectionPool] Failed to create connection: "
            << e.what() << endl;
        return nullptr;
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// isConnectionValid — lightweight liveness check
// ═════════════════════════════════════════════════════════════════════════════
bool DBConnectionPool::isConnectionValid(sql::Connection* conn) {
    if (!conn) return false;
    try {
        return conn->isValid();
    } catch (...) {
        return false;
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// getConnection — checkout a connection (blocks if pool exhausted)
// ═════════════════════════════════════════════════════════════════════════════
unique_ptr<sql::Connection> DBConnectionPool::getConnection() {
    unique_lock<mutex> lock(mutex_);

    while (true) {
        if (shutdownFlag_) {
            throw runtime_error("[DBConnectionPool] Pool has been shut down.");
        }

        // 1. Try to return an idle, valid connection
        while (!pool_.empty()) {
            auto conn = move(pool_.front());
            pool_.pop();

            if (isConnectionValid(conn.get())) {
                // Ensure we're on the right schema
                try {
                    conn->setSchema(config::DB_NAME);
                } catch (...) { /* db may not exist yet */ }
                return conn;
            }

            // Dead connection — discard and reduce count
            --activeCount_;
        }

        // 2. Pool is empty — can we create a new one?
        if (activeCount_ < config::POOL_MAX_SIZE) {
            ++activeCount_;
            lock.unlock();

            auto conn = createConnection();
            if (conn) {
                return conn;
            }

            // Creation failed — roll back the count
            lock.lock();
            --activeCount_;
            throw runtime_error("[DBConnectionPool] Failed to create new connection.");
        }

        // 3. At max capacity — wait for a release
        cv_.wait(lock);
    }
}

// ═════════════════════════════════════════════════════════════════════════════
// releaseConnection — return a connection to the pool
// ═════════════════════════════════════════════════════════════════════════════
void DBConnectionPool::releaseConnection(unique_ptr<sql::Connection> conn) {
    lock_guard<mutex> lock(mutex_);

    if (!conn || !isConnectionValid(conn.get())) {
        // Connection is dead — just decrement count
        if (conn) --activeCount_;
        cv_.notify_one();
        return;
    }

    // Reset to clean state
    try {
        if (!conn->getAutoCommit()) {
            conn->rollback();
            conn->setAutoCommit(true);
        }
    } catch (...) {
        // If reset fails, discard the connection
        --activeCount_;
        cv_.notify_one();
        return;
    }

    pool_.push(move(conn));
    cv_.notify_one();
}

// ═════════════════════════════════════════════════════════════════════════════
// shutdown — drain all connections
// ═════════════════════════════════════════════════════════════════════════════
void DBConnectionPool::shutdown() {
    lock_guard<mutex> lock(mutex_);
    shutdownFlag_ = true;

    while (!pool_.empty()) {
        auto conn = move(pool_.front());
        pool_.pop();
        try {
            if (conn) conn->close();
        } catch (...) {}
        --activeCount_;
    }

    cv_.notify_all();
    cout << "[DBConnectionPool] Shutdown complete." << endl;
}

// ═════════════════════════════════════════════════════════════════════════════
// availableConnections — diagnostic
// ═════════════════════════════════════════════════════════════════════════════
int DBConnectionPool::availableConnections() const {
    lock_guard<mutex> lock(mutex_);
    return static_cast<int>(pool_.size());
}

} // namespace flexistore
