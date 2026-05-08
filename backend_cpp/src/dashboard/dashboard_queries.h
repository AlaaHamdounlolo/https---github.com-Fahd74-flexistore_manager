#ifndef FLEXISTORE_DASHBOARD_QUERIES_H
#define FLEXISTORE_DASHBOARD_QUERIES_H

#include "core/ffi_types.h"

/*******************************************************************************
 * dashboard_queries.h — FlexiStore Manager
 * 
 * Provides dashboard statistics.
 ******************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns a JSON string containing dashboard statistics.
 * 
 * @param user_id ID of the user requesting the stats (for potential audit logging).
 * @return JSON string allocated on the heap. Must be freed by the caller via free_ffi_string.
 *         Example on success: {"total_clients": 150, "low_stock": 5, "total_sales": 2500.50}
 *         Example on error: {"error": "Database query failed"}
 */
FLEXISTORE_EXPORT const char* get_dashboard_stats(int user_id);

#ifdef __cplusplus
}
#endif

#endif // FLEXISTORE_DASHBOARD_QUERIES_H
