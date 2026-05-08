const std = @import("std");
const zap = @import("zap");

const umboard = @import("umboard");

const indexTemplate = @embedFile("template/index.html");
const dashboardTemplate = @embedFile("template/dashboard.html");
const usersListTemplate = @embedFile("template/users/list.html");

fn AdminRoute(comptime handler: anytype) type {
    return umboard.shortcuts.RoleRoute("admin", handler);
}

pub fn register(r: *zap.Router, c: *umboard.core.context.Context) !void {
    try AdminRoute(admin).register(r, "/umboard/admin", c);
    try AdminRoute(dashboard).register(r, "/umboard/admin/dashboard", c);
    try AdminRoute(usersList).register(r, "/umboard/admin/users/list", c);
}

fn admin(r: zap.Request, s: umboard.core.http.Scope) !void {
    var arena = std.heap.ArenaAllocator.init(s.context.allocator);
    defer arena.deinit();

    const session_key = umboard.helpers.keyOfSession(arena.allocator(), r);
    defer arena.allocator().free(session_key);

    const info = umboard.helpers.infoForSession(arena.allocator(), s.db, session_key);

    try umboard.shortcuts.renderWith(r, indexTemplate, .{ .username = info.username });
}

fn dashboard(r: zap.Request, s: umboard.core.http.Scope) !void {
    var arena = std.heap.ArenaAllocator.init(s.context.allocator);
    defer arena.deinit();

    const dbc = umboard.core.db.c;

    const session_key = umboard.helpers.keyOfSession(arena.allocator(), r);
    defer arena.allocator().free(session_key);

    const sql =
        \\SELECT u.username, u.role, u.last_logged_in, u.created_at
        \\FROM auth_user u
        \\JOIN auth_session s ON u.username = s.username
        \\WHERE s.key = ?
        \\  AND s.revoked = 0
        \\  AND s.expires_at > unixepoch()
        \\LIMIT 1
    ;

    var stmt: ?*dbc.sqlite3_stmt = null;
    if (dbc.sqlite3_prepare_v2(s.db, sql, -1, &stmt, null) != dbc.SQLITE_OK) {
        std.debug.print("failed to prepare dashboard query\n", .{});
        return error.DatabaseError;
    }
    defer _ = dbc.sqlite3_finalize(stmt.?);

    if (dbc.sqlite3_bind_text(stmt.?, 1, session_key.ptr, @intCast(session_key.len), null) != dbc.SQLITE_OK) {
        std.debug.print("failed to bind session key\n", .{});
        return error.DatabaseError;
    }

    if (dbc.sqlite3_step(stmt.?) == dbc.SQLITE_ROW) {
        const username_ptr = dbc.sqlite3_column_text(stmt.?, 0);
        const username_len = dbc.sqlite3_column_bytes(stmt.?, 0);
        const username = username_ptr[0..@intCast(username_len)];

        const role_ptr = dbc.sqlite3_column_text(stmt.?, 1);
        const role_len = dbc.sqlite3_column_bytes(stmt.?, 1);
        const role = role_ptr[0..@intCast(role_len)];

        const last_login = dbc.sqlite3_column_int64(stmt.?, 2);
        const created_at = dbc.sqlite3_column_int64(stmt.?, 3);

        const last_login_str = if (last_login > 0)
            try umboard.utils.formatTimestamp(arena.allocator(), last_login)
        else
            try arena.allocator().dupe(u8, "Never");

        const created_str = try umboard.utils.formatTimestamp(arena.allocator(), created_at);

        const data = .{
            .username = username,
            .role = role,
            .last_login = last_login_str,
            .created_at = created_str,
        };

        try umboard.shortcuts.renderWith(r, dashboardTemplate, data);
    } else {
        return error.Unauthorized;
    }
}

const User = struct {
    username: []const u8,
    role: []const u8,
    created_at: []const u8,
    updated_at: []const u8,
    initials: []const u8,
    badge_color: []const u8,
};

fn usersList(r: zap.Request, s: umboard.core.http.Scope) !void {
    var arena = std.heap.ArenaAllocator.init(s.context.allocator);
    defer arena.deinit();

    const dbc = umboard.core.db.c;

    const sql =
        \\SELECT username, role, created_at, updated_at
        \\FROM auth_user
        \\WHERE role IN ('staff', 'user')
        \\ORDER BY created_at DESC
    ;

    var stmt: ?*dbc.sqlite3_stmt = null;
    if (dbc.sqlite3_prepare_v2(s.db, sql, -1, &stmt, null) != dbc.SQLITE_OK) {
        std.debug.print("failed to prepare users query\n", .{});
        return error.DatabaseError;
    }
    defer _ = dbc.sqlite3_finalize(stmt.?);

    var users = std.array_list.AlignedManaged(User, null).init(arena.allocator());
    defer users.deinit();

    while (dbc.sqlite3_step(stmt.?) == dbc.SQLITE_ROW) {
        const username_ptr = dbc.sqlite3_column_text(stmt.?, 0);
        const username_len = dbc.sqlite3_column_bytes(stmt.?, 0);
        const username = username_ptr[0..@intCast(username_len)];

        const role_ptr = dbc.sqlite3_column_text(stmt.?, 1);
        const role_len = dbc.sqlite3_column_bytes(stmt.?, 1);
        const role = role_ptr[0..@intCast(role_len)];

        const created_at = dbc.sqlite3_column_int64(stmt.?, 2);
        const updated_at = dbc.sqlite3_column_int64(stmt.?, 3);

        const user_copy = try arena.allocator().dupe(u8, username);
        const role_copy = try arena.allocator().dupe(u8, role);

        const created_str = try umboard.utils.formatTimestamp(arena.allocator(), created_at);
        const updated_str = try umboard.utils.formatTimestamp(arena.allocator(), updated_at);

        const initials = try umboard.utils.getInitials(arena.allocator(), username);
        const badge_color = if (std.mem.eql(u8, role, "staff")) "badge-secondary" else "badge-accent";

        try users.append(.{
            .username = user_copy,
            .role = role_copy,
            .created_at = created_str,
            .updated_at = updated_str,
            .initials = initials,
            .badge_color = badge_color,
        });
    }

    const data = .{ .users = users.items };
    try umboard.shortcuts.renderWith(r, usersListTemplate, data);
}
