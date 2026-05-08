#ifndef FLEXISTORE_JSON_BUILDER_H
#define FLEXISTORE_JSON_BUILDER_H

#include <string>
#include <vector>
#include <sstream>
#include "ffi_types.h"

namespace sql {
    class ResultSet;
}

namespace flexistore {

class JsonBuilder {
public:
    JsonBuilder() : first_item_(true) {}
    ~JsonBuilder() = default;

    void start_object();
    void start_object(const std::string& key);
    void end_object();
    void start_array();
    void start_array(const std::string& key);
    void end_array();

    void add_string(const std::string& key, const std::string& value);
    void add_int(const std::string& key, int value);
    void add_double(const std::string& key, double value);
    void add_bool(const std::string& key, bool value);
    void add_null(const std::string& key);

    void add_string_element(const std::string& value);
    void add_int_element(int value);
    void add_double_element(double value);
    void add_bool_element(bool value);
    void add_null_element();

    // Utility to serialize an entire ResultSet to a JSON array of objects
    static std::string result_set_to_json(sql::ResultSet* res);

    std::string build() const { return buffer_.str(); }

private:
    std::ostringstream buffer_;
    std::vector<bool> is_object_stack_; // true if current container is object, false if array
    bool first_item_;

    void prepare_insert(bool is_key_value = false);
    static std::string escape_string(const std::string& input);
};

// Helper to allocate a C-string on the heap for FFI.
// The resulting pointer must be freed by calling free_ffi_string() from Dart.
const char* allocate_ffi_string(const std::string& str);

} // namespace flexistore

extern "C" {
    // Exported function to free memory allocated for JSON strings returned to Flutter.
    FLEXISTORE_EXPORT void free_ffi_string(const char* ptr);
}

#endif // FLEXISTORE_JSON_BUILDER_H
