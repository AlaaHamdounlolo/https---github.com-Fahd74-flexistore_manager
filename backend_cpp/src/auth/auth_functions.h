#ifndef FLEXISTORE_AUTH_FUNCTIONS_H
#define FLEXISTORE_AUTH_FUNCTIONS_H

#include "core/ffi_types.h"

extern "C" {

/**
 * Validates the user credentials against the database.
 * If successful, activates the session in SessionManager and returns FFI_SUCCESS.
 * Otherwise, returns the appropriate error code.
 */
FLEXISTORE_EXPORT int login(const char* username, const char* password_hash);

/**
 * Clears the active session from the SessionManager.
 * Always returns FFI_SUCCESS.
 */
FLEXISTORE_EXPORT int logout();

}

#endif // FLEXISTORE_AUTH_FUNCTIONS_H
