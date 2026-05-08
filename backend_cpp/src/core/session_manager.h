#ifndef FLEXISTORE_SESSION_MANAGER_H
#define FLEXISTORE_SESSION_MANAGER_H

#include <string>
#include <shared_mutex>
#include "ffi_types.h"

namespace flexistore {

class SessionManager {
public:
    // ── Singleton Access ─────────────────────────────────────────────────────
    static SessionManager& get_instance();

    // Non-copyable, non-movable
    SessionManager(const SessionManager&) = delete;
    SessionManager& operator=(const SessionManager&) = delete;
    SessionManager(SessionManager&&) = delete;
    SessionManager& operator=(SessionManager&&) = delete;

    // ── Mutators ─────────────────────────────────────────────────────────────
    void set_session(int user_id, const std::string& role, const std::string& name);
    void clear_session();

    // ── Accessors ────────────────────────────────────────────────────────────
    int get_active_user_id() const;
    std::string get_active_role() const;
    std::string get_active_name() const;
    bool is_logged_in() const;

private:
    SessionManager() : current_user_id_(-1), current_role_(""), current_name_("") {}
    ~SessionManager() = default;

    mutable std::shared_mutex mutex_;
    int current_user_id_;
    std::string current_role_;
    std::string current_name_;
};

} // namespace flexistore

// ── Exported FFI functions for Flutter to query session state ─────────────────
extern "C" {
    /// Returns the user_id of the currently logged-in user, or -1 if no session.
    FLEXISTORE_EXPORT int get_current_user_id();

    /// Returns the role string of the currently logged-in user.
    /// Caller must free with free_ffi_string().
    FLEXISTORE_EXPORT const char* get_current_role();

    /// Returns the display name of the currently logged-in user.
    /// Caller must free with free_ffi_string().
    FLEXISTORE_EXPORT const char* get_current_user_name();
}

#endif // FLEXISTORE_SESSION_MANAGER_H
