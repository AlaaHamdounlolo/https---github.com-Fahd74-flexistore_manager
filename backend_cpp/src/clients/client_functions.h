#ifndef FLEXISTORE_CLIENT_FUNCTIONS_H
#define FLEXISTORE_CLIENT_FUNCTIONS_H

#include "../core/ffi_types.h"

extern "C" {
    FLEXISTORE_EXPORT int add_client(int user_id, 
                                    const char* name, 
                                    const char* phone, 
                                    const char* email, 
                                    const char* address, 
                                    const char* notes);

    FLEXISTORE_EXPORT int update_client(int user_id, 
                                        int client_id, 
                                        const char* name, 
                                        const char* phone,
                                        const char* email,
                                        const char* address,
                                        const char* notes);

    FLEXISTORE_EXPORT int delete_client(int user_id, int client_id);
    
    FLEXISTORE_EXPORT const char* get_all_clients(int user_id);
}

#endif // FLEXISTORE_CLIENT_FUNCTIONS_H