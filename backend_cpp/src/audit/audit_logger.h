#ifndef FLEXISTORE_AUDIT_LOGGER_H
#define FLEXISTORE_AUDIT_LOGGER_H

#include "../core/ffi_types.h"

extern "C" {
    FLEXISTORE_EXPORT void log_inventory_change(int product_id, int user_id, const char* action_type, int qty_changed);
    FLEXISTORE_EXPORT void log_transaction(int user_id, const char* action_type, double amount);
    FLEXISTORE_EXPORT const char* get_inventory_logs();
    FLEXISTORE_EXPORT const char* get_transaction_logs();
}

#endif // FLEXISTORE_AUDIT_LOGGER_H
