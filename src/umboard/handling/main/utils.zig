const std = @import("std");
const umboard = @import("umboard");

const dbc = umboard.core.db.c;

pub fn roleForSession(scope: umboard.core.http.Scope, session_key: []const u8) ![]const u8 {
    const sql =
        \\SELECT u.role
        \\FROM auth_session s
        \\JOIN auth_user u ON u.username = s.username
        \\WHERE s.key = ?
        \\LIMIT 1
    ;

    var stmt: ?*dbc.sqlite3_stmt = null;
    if (dbc.sqlite3_prepare_v2(scope.db, sql, -1, &stmt, null) != dbc.SQLITE_OK) {
        return error.DatabaseError;
    }
    defer _ = dbc.sqlite3_finalize(stmt.?);

    if (dbc.sqlite3_bind_text(stmt.?, 1, session_key.ptr, @intCast(session_key.len), null) != dbc.SQLITE_OK) {
        return error.DatabaseError;
    }

    switch (dbc.sqlite3_step(stmt.?)) {
        dbc.SQLITE_ROW => {
            const role_ptr = dbc.sqlite3_column_text(stmt.?, 0) orelse return error.DatabaseError;
            const role_len: usize = @intCast(dbc.sqlite3_column_bytes(stmt.?, 0));
            return scope.context.allocator.dupe(u8, @as([*]const u8, @ptrCast(role_ptr))[0..role_len]);
        },
        else => return error.DatabaseError,
    }
}
