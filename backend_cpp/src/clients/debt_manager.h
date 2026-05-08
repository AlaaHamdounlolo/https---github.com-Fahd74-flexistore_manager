#ifndef FLEXISTORE_DEBT_MANAGER_H
#define FLEXISTORE_DEBT_MANAGER_H

#include "../core/ffi_types.h"
#include <cppconn/connection.h>

namespace flexistore {

    /**
     * Internal C++ API for safely updating a client's debt.
     * This function MUST be used by all other modules (Installments, Returns, POS)
     * instead of writing raw UPDATE clients SET total_debt queries.
     * 
     * @param conn Open database connection (can be part of an active transaction)
     * @param client_id ID of the client
     * @param amount_change Amount to add (positive) or subtract (negative)
     * @return true if successful, false if client not found or would result in negative debt
     */
    bool update_client_debt(sql::Connection* conn, int client_id, double amount_change);

}

#endif // FLEXISTORE_DEBT_MANAGER_H
