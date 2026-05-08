#ifndef FLEXISTORE_DB_INITIALIZER_H
#define FLEXISTORE_DB_INITIALIZER_H

#include "core/ffi_types.h"

/*******************************************************************************
 * db_initializer.h — FlexiStore Manager
 *
 * Ensures the `flexistore` database and all 9 core tables exist.
 * Called once at application startup from Flutter before any other operation.
 *
 * EXPORTED FUNCTION:
 *   initialize_database() → int (FFI_SUCCESS or error code)
 ******************************************************************************/

FLEXISTORE_EXPORT int initialize_database();

#endif // FLEXISTORE_DB_INITIALIZER_H
