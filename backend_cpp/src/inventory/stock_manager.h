#ifndef FLEXISTORE_STOCK_MANAGER_H
#define FLEXISTORE_STOCK_MANAGER_H

#include "../core/ffi_types.h"

// Forward declaration
namespace sql {
    class Connection;
}

namespace flexistore {

/**
 * Updates the stock quantity of a product.
 * Positive qty = restock/return, Negative qty = sale.
 *
 * @param product_id The ID of the product.
 * @param qty The amount to add (can be negative).
 * @param user_id The ID of the user performing the operation.
 * @param conn Optional DB connection to use (for transactions from Team 4/6).
 *             If nullptr, it gets its own connection from the pool.
 * @return FFI_SUCCESS on success, or an FFI_ERROR code.
 */
int restock_product(int product_id, int qty, int user_id, sql::Connection* conn = nullptr);

}

#endif // FLEXISTORE_STOCK_MANAGER_H
