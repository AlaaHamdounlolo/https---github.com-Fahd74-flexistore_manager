#ifndef FLEXISTORE_INSTALLMENT_FUNCTIONS_H
#define FLEXISTORE_INSTALLMENT_FUNCTIONS_H

#include "../core/ffi_types.h"

/*******************************************************************************
 * installment_functions.h — FlexiStore Manager (Team 5: Installments)
 *
 * FFI exports for installment plan management.
 *
 * Workflow:
 *   After pos_process_sale() creates an invoice with payment_type='installment',
 *   the Flutter frontend calls create_installment_plan() to create the
 *   payment schedule and update the client's total_debt.
 ******************************************************************************/

extern "C" {

    /**
     * Creates a new installment plan linked to an invoice and client.
     *
     * Steps:
     *   1. Calculate monthly_installment = total_amount / months
     *   2. INSERT into `installments` table
     *   3. UPDATE `clients.total_debt += total_amount`
     *
     * @param user_id       The user performing the operation (for audit).
     * @param client_id     The client taking the installment plan.
     * @param invoice_id    The invoice this plan is linked to.
     * @param total_amount  The full amount to be paid in installments.
     * @param months        Number of monthly payments.
     * @return FFI_SUCCESS on success, or a negative FFI error code.
     */
    FLEXISTORE_EXPORT int create_installment_plan(
        int user_id,
        int client_id,
        int invoice_id,
        double total_amount,
        int months
    );
}

#endif // FLEXISTORE_INSTALLMENT_FUNCTIONS_H
