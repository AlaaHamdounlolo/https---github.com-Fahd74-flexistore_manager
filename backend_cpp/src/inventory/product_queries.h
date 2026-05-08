#ifndef FLEXISTORE_PRODUCT_QUERIES_H
#define FLEXISTORE_PRODUCT_QUERIES_H

#include "../core/ffi_types.h"

extern "C" {
    FLEXISTORE_EXPORT const char* get_all_products(int user_id);
    FLEXISTORE_EXPORT const char* get_inventory_stats(int user_id);
    FLEXISTORE_EXPORT const char* get_filtered_inventory(int user_id, const char* search_query, const char* category);
    FLEXISTORE_EXPORT const char* get_product_by_barcode(int user_id, const char* barcode);
    FLEXISTORE_EXPORT const char* get_low_stock_products(int user_id, int threshold);
}

#endif // FLEXISTORE_PRODUCT_QUERIES_H
