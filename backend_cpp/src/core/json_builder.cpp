#include "json_builder.h"
#include <mysql/jdbc.h>
#include <iomanip>
#include <cstring>
#include <cstdlib>

namespace flexistore {

// Helper to properly escape strings for JSON
std::string JsonBuilder::escape_string(const std::string& input) {
    std::ostringstream ss;
    for (char c : input) {
        switch (c) {
            case '"':  ss << "\\\""; break;
            case '\\': ss << "\\\\"; break;
            case '\b': ss << "\\b"; break;
            case '\f': ss << "\\f"; break;
            case '\n': ss << "\\n"; break;
            case '\r': ss << "\\r"; break;
            case '\t': ss << "\\t"; break;
            default:
                if ('\x00' <= c && c <= '\x1f') {
                    ss << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(c);
                } else {
                    ss << c;
                }
        }
    }
    return ss.str();
}

void JsonBuilder::prepare_insert(bool is_key_value) {
    if (!first_item_) {
        buffer_ << ",";
    }
    first_item_ = false;
}

void JsonBuilder::start_object() {
    prepare_insert();
    buffer_ << "{";
    is_object_stack_.push_back(true);
    first_item_ = true;
}

void JsonBuilder::start_object(const std::string& key) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":{";
    is_object_stack_.push_back(true);
    first_item_ = true;
}

void JsonBuilder::end_object() {
    buffer_ << "}";
    if (!is_object_stack_.empty()) {
        is_object_stack_.pop_back();
    }
    first_item_ = false;
}

void JsonBuilder::start_array() {
    prepare_insert();
    buffer_ << "[";
    is_object_stack_.push_back(false);
    first_item_ = true;
}

void JsonBuilder::start_array(const std::string& key) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":[";
    is_object_stack_.push_back(false);
    first_item_ = true;
}

void JsonBuilder::end_array() {
    buffer_ << "]";
    if (!is_object_stack_.empty()) {
        is_object_stack_.pop_back();
    }
    first_item_ = false;
}

void JsonBuilder::add_string(const std::string& key, const std::string& value) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":\"" << escape_string(value) << "\"";
}

void JsonBuilder::add_int(const std::string& key, int value) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":" << value;
}

void JsonBuilder::add_double(const std::string& key, double value) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":" << value;
}

void JsonBuilder::add_bool(const std::string& key, bool value) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":" << (value ? "true" : "false");
}

void JsonBuilder::add_null(const std::string& key) {
    prepare_insert(true);
    buffer_ << "\"" << escape_string(key) << "\":null";
}

void JsonBuilder::add_string_element(const std::string& value) {
    prepare_insert();
    buffer_ << "\"" << escape_string(value) << "\"";
}

void JsonBuilder::add_int_element(int value) {
    prepare_insert();
    buffer_ << value;
}

void JsonBuilder::add_double_element(double value) {
    prepare_insert();
    buffer_ << value;
}

void JsonBuilder::add_bool_element(bool value) {
    prepare_insert();
    buffer_ << (value ? "true" : "false");
}

void JsonBuilder::add_null_element() {
    prepare_insert();
    buffer_ << "null";
}

std::string JsonBuilder::result_set_to_json(sql::ResultSet* res) {
    if (!res) return "[]";

    sql::ResultSetMetaData* meta = res->getMetaData();
    unsigned int num_columns = meta->getColumnCount();

    JsonBuilder builder;
    builder.start_array();

    while (res->next()) {
        builder.start_object();
        for (unsigned int i = 1; i <= num_columns; ++i) {
            std::string col_name = meta->getColumnName(i);
            int col_type = meta->getColumnType(i);

            if (res->isNull(i)) {
                builder.add_null(col_name);
                continue;
            }

            switch(col_type) {
                case sql::DataType::TINYINT:
                case sql::DataType::SMALLINT:
                case sql::DataType::INTEGER:
                    builder.add_int(col_name, res->getInt(i));
                    break;
                case sql::DataType::BIGINT:
                    // Use string representation for BIGINT to avoid JS number precision issues
                    builder.add_string(col_name, res->getString(i));
                    break;
                case sql::DataType::REAL:
                case sql::DataType::DOUBLE:
                    builder.add_double(col_name, res->getDouble(i));
                    break;
                case sql::DataType::DECIMAL:
                case sql::DataType::NUMERIC: {
                    // MySQL Connector/C++ on Windows often corrupts the heap when calling getDouble() 
                    // directly on DECIMAL/NUMERIC types due to CRT ABI mismatches.
                    // Fetching as string and converting manually bypasses this issue.
                    std::string val_str = res->getString(i);
                    try {
                        builder.add_double(col_name, std::stod(val_str));
                    } catch (...) {
                        builder.add_double(col_name, 0.0);
                    }
                    break;
                }
                case sql::DataType::BIT:
                    builder.add_bool(col_name, res->getBoolean(i));
                    break;
                default:
                    // VARCHAR, DATE, TIMESTAMP, TEXT, etc.
                    builder.add_string(col_name, res->getString(i));
                    break;
            }
        }
        builder.end_object();
    }
    builder.end_array();

    return builder.build();
}

const char* allocate_ffi_string(const std::string& str) {
    const size_t len = str.size() + 1; // +1 for null terminator
    char* buf = static_cast<char*>(std::malloc(len));
    if (buf) {
        std::memcpy(buf, str.c_str(), len);
    }
    return buf;
}

} // namespace flexistore

extern "C" {
    FLEXISTORE_EXPORT void free_ffi_string(const char* ptr) {
        if (ptr) {
            std::free(const_cast<char*>(ptr));
        }
    }
}
