#ifndef FLEXISTORE_PRODUCT_FUNCTIONS_H
#define FLEXISTORE_PRODUCT_FUNCTIONS_H

#include "../core/ffi_types.h"

extern "C" {
    FLEXISTORE_EXPORT int add_product(int user_id, const char* barcode, const char* name, const char* category, double purchase_price, double selling_price, int stock_quantity);
    FLEXISTORE_EXPORT int update_product(int user_id, int product_id, const char* barcode, const char* name, const char* category, double purchase_price, double selling_price);
    FLEXISTORE_EXPORT int soft_delete_product(int user_id, int product_id);
}

#endif // FLEXISTORE_PRODUCT_FUNCTIONS_H
