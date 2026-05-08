#include "session_manager.h"
#include "json_builder.h"
#include <mutex>

namespace flexistore {

// ═════════════════════════════════════════════════════════════════════════════
// Singleton Access
// ═════════════════════════════════════════════════════════════════════════════
SessionManager& SessionManager::get_instance() {
    static SessionManager instance;
    return instance;
}

// ═════════════════════════════════════════════════════════════════════════════
// Mutators
// ═════════════════════════════════════════════════════════════════════════════
void SessionManager::set_session(int user_id, const std::string& role, const std::string& name) {
    std::unique_lock<std::shared_mutex> lock(mutex_);
    current_user_id_ = user_id;
    current_role_ = role;
    current_name_ = name;
}

void SessionManager::clear_session() {
    std::unique_lock<std::shared_mutex> lock(mutex_);
    current_user_id_ = -1;
    current_role_.clear();
    current_name_.clear();
}

// ═════════════════════════════════════════════════════════════════════════════
// Accessors
// ═════════════════════════════════════════════════════════════════════════════
int SessionManager::get_active_user_id() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_user_id_;
}

std::string SessionManager::get_active_role() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_role_;
}

std::string SessionManager::get_active_name() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_name_;
}

bool SessionManager::is_logged_in() const {
    std::shared_lock<std::shared_mutex> lock(mutex_);
    return current_user_id_ != -1;
}

} // namespace flexistore

// ═════════════════════════════════════════════════════════════════════════════
// Exported FFI Functions — callable from Flutter via dart:ffi
// ═════════════════════════════════════════════════════════════════════════════
extern "C" {

FLEXISTORE_EXPORT int get_current_user_id() {
    return flexistore::SessionManager::get_instance().get_active_user_id();
}

FLEXISTORE_EXPORT const char* get_current_role() {
    std::string role = flexistore::SessionManager::get_instance().get_active_role();
    return flexistore::allocate_ffi_string(role);
}

FLEXISTORE_EXPORT const char* get_current_user_name() {
    std::string name = flexistore::SessionManager::get_instance().get_active_name();
    return flexistore::allocate_ffi_string(name);
}

} // extern "C"
