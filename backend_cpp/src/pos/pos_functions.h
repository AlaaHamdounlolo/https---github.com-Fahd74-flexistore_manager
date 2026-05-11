#ifndef FLEXISTORE_POS_FUNCTIONS_H
#define FLEXISTORE_POS_FUNCTIONS_H

#include "../core/ffi_types.h"

/*******************************************************************************
 * pos_functions.h — FlexiStore Manager (Team 4: POS/Sales)
 *
 * FFI exports for the Point-of-Sale transaction engine.
 *
 * Transaction flow:
 *   1. pos_validate_stock()   — Pre-flight check (optional, UI-side guard)
 *   2. pos_process_sale()     — Atomic sale: validate → invoice → deduct → audit
 *   3. pos_get_invoice()      — Retrieve invoice + items as JSON for preview/PDF
 *
 * Return codes:
 *   pos_process_sale() returns invoice_id (>0) on success, or FFI_ERROR_POS_*
 ******************************************************************************/

extern "C" {

    /**
     * Validates stock availability for a list of cart items.
     *
     * @param items_json  JSON array: [{"product_id":1,"quantity":2}, ...]
     * @return FFI_SUCCESS if all items have sufficient stock,
     *         FFI_ERROR_POS_INSUFFICIENT_STOCK if any item would go negative,
     *         FFI_ERROR_INVALID_INPUT if JSON is null or malformed.
     */
    FLEXISTORE_EXPORT int pos_validate_stock(const char* items_json);

    /**
     * Processes a complete sale within a single DB transaction.
     *
     * Steps (all-or-nothing):
     *   1. Validate stock for every item (SELECT ... FOR UPDATE)
     *   2. INSERT into `invoices`
     *   3. INSERT each row into `invoice_items`
     *   4. UPDATE `products.stock_quantity` for each item
     *   5. Log inventory changes via audit_logger
     *   6. Log transaction via audit_logger
     *   7. COMMIT
     *
     * @param user_id       The cashier's user ID (for audit trail).
     * @param client_id     The client ID, or 0 for Guest (sets NULL in DB).
     * @param items_json    JSON array: [{"product_id":1,"quantity":2,"unit_price":10.50}, ...]
     * @param total_amount  The gross total before discount.
     * @param net_amount    The net total after discount.
     * @param payment_type  "cash" or "installment".
     * @return invoice_id (>0) on success, or a negative FFI error code.
     */
    FLEXISTORE_EXPORT int pos_process_sale(
        int user_id,
        int client_id,
        const char* items_json,
        double total_amount,
        double net_amount,
        const char* payment_type
    );

    /**
     * Retrieves a single invoice with its items as a JSON object.
     *
     * Returned JSON:
     * {
     *   "id": 42,
     *   "client_name": "Ahmed" | "Guest",
     *   "cashier_name": "admin",
     *   "total_amount": 150.00,
     *   "net_amount": 140.00,
     *   "payment_type": "cash",
     *   "created_at": "2026-05-11 12:00:00",
     *   "items": [
     *     {"product_name":"iPhone Case","quantity":2,"unit_price":25.00,"line_total":50.00},
     *     ...
     *   ]
     * }
     *
     * Caller must free with free_ffi_string().
     *
     * @param invoice_id  The invoice to retrieve.
     * @return JSON string, or error JSON if not found.
     */
    FLEXISTORE_EXPORT const char* pos_get_invoice(int invoice_id);
}

#endif // FLEXISTORE_POS_FUNCTIONS_H
