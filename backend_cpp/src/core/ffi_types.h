#ifndef FLEXISTORE_FFI_TYPES_H
#define FLEXISTORE_FFI_TYPES_H

/*******************************************************************************
 * ffi_types.h — FlexiStore Manager
 * 
 * Unified FFI contract definitions used by ALL teams.
 * 
 * RULES:
 *   - Read  functions return: const char* (JSON string)
 *   - Write functions return: int         (one of the codes below)
 *   - All exported functions MUST use the FLEXISTORE_EXPORT macro.
 *   - Every exported function receives user_id for audit logging.
 *
 * ADDING NEW CODES:
 *   - Success codes are >= 0
 *   - Error codes are < 0
 *   - Reserve ranges per team to avoid collisions:
 *       General    :   0 to  -99
 *       Auth       : -100 to -199
 *       Inventory  : -200 to -299
 *       Clients    : -300 to -399
 *       POS/Sales  : -400 to -499
 *       Installments: -500 to -599
 *       Returns    : -600 to -699
 *       Audit      : -700 to -799
 ******************************************************************************/

// ── DLL Export Macro ─────────────────────────────────────────────────────────
#ifdef _WIN32
    #ifdef FLEXISTORE_EXPORTS
        #define FLEXISTORE_EXPORT extern "C" __declspec(dllexport)
    #else
        #define FLEXISTORE_EXPORT extern "C" __declspec(dllimport)
    #endif
#else
    #define FLEXISTORE_EXPORT extern "C" __attribute__((visibility("default")))
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// GENERAL CODES (0 to -99)
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_SUCCESS                  =   0;  // Operation completed successfully
constexpr int FFI_ERROR_UNKNOWN            =  -1;  // Unclassified / unexpected error
constexpr int FFI_ERROR_DB_CONNECTION      =  -2;  // Failed to acquire DB connection
constexpr int FFI_ERROR_DB_QUERY           =  -3;  // SQL query execution failed
constexpr int FFI_ERROR_DB_TRANSACTION     =  -4;  // Transaction commit/rollback failed
constexpr int FFI_ERROR_INVALID_INPUT      =  -5;  // Null pointer, empty string, bad param
constexpr int FFI_ERROR_NOT_FOUND          =  -6;  // Requested record does not exist
constexpr int FFI_ERROR_DUPLICATE          =  -7;  // Unique constraint violation
constexpr int FFI_ERROR_PERMISSION_DENIED  =  -8;  // User role lacks permission
constexpr int FFI_ERROR_JSON_BUILD         =  -9;  // Failed to serialize result to JSON
constexpr int FFI_ERROR_MEMORY_ALLOC       = -10;  // Memory allocation failure
constexpr int FFI_ERROR_DB_INIT            = -11;  // Database/table initialization failed

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH CODES (-100 to -199)   — Team 1
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_AUTH_INVALID_CREDS = -100; // Wrong username or password
constexpr int FFI_ERROR_AUTH_USER_INACTIVE = -101; // User account is disabled
constexpr int FFI_ERROR_AUTH_SESSION_FAIL  = -102; // Failed to create/store session

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY CODES (-200 to -299)   — Team 2
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_INV_PRODUCT_EXISTS    = -200; // Barcode already exists
constexpr int FFI_ERROR_INV_INVALID_PRICE     = -201; // Negative or zero price
constexpr int FFI_ERROR_INV_INVALID_QUANTITY  = -202; // Negative stock quantity
constexpr int FFI_ERROR_INV_PRODUCT_INACTIVE  = -203; // Attempting op on soft-deleted product
constexpr int FFI_ERROR_INV_DUPLICATE_BARCODE = -204; // Barcode already exists (duplicate check)
constexpr int FFI_ERROR_INV_PRODUCT_NOT_FOUND = -205; // Product ID does not exist or is inactive
constexpr int FFI_ERROR_INV_INSUFFICIENT_STOCK= -206; // Stock would go negative after operation

// ═══════════════════════════════════════════════════════════════════════════════
// CLIENTS CODES (-300 to -399)   — Team 3
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_CLI_HAS_DEBT       = -300; // Cannot delete client with outstanding debt
constexpr int FFI_ERROR_CLI_PHONE_EXISTS   = -301; // Phone number already registered
constexpr int FFI_ERROR_CLI_INVALID_DEBT   = -302; // Debt update would result in negative total

// ═══════════════════════════════════════════════════════════════════════════════
// POS / SALES CODES (-400 to -499)   — Team 4
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_POS_EMPTY_CART        = -400; // Cart is empty at checkout
constexpr int FFI_ERROR_POS_INSUFFICIENT_STOCK= -401; // Not enough stock for requested qty
constexpr int FFI_ERROR_POS_INVALID_CLIENT    = -402; // Installment sale requires valid client
constexpr int FFI_ERROR_POS_INVOICE_FAILED    = -403; // Failed to create invoice record

// ═══════════════════════════════════════════════════════════════════════════════
// INSTALLMENTS CODES (-500 to -599)   — Team 5
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_INST_INVALID_MONTHS   = -500; // Months must be > 0
constexpr int FFI_ERROR_INST_INVALID_AMOUNT   = -501; // Amount must be > 0
constexpr int FFI_ERROR_INST_PLAN_CLOSED      = -502; // Installment plan already fully paid
constexpr int FFI_ERROR_INST_OVERPAYMENT      = -503; // Payment exceeds remaining amount

// ═══════════════════════════════════════════════════════════════════════════════
// RETURNS CODES (-600 to -699)   — Team 6
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_RET_INVOICE_NOT_FOUND = -600; // Original invoice does not exist
constexpr int FFI_ERROR_RET_ALREADY_RETURNED  = -601; // Item(s) already returned
constexpr int FFI_ERROR_RET_INVALID_QUANTITY  = -602; // Return qty exceeds original qty

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT CODES (-700 to -799)   — Team 7
// ═══════════════════════════════════════════════════════════════════════════════
constexpr int FFI_ERROR_AUDIT_LOG_FAILED   = -700; // Failed to write audit log entry

#endif // FLEXISTORE_FFI_TYPES_H
