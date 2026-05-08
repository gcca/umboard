const std = @import("std");
const zap = @import("zap");
const umboard = @import("umboard");
const utils = @import("utils.zig");
const Context = umboard.core.context.Context;

const signInTemplate = @embedFile("template/signin.html");

var context: *Context = undefined;

pub fn register(router: *zap.Router, ctx: *Context) !void {
    context = ctx;
    try router.handle_func_unbound("/umboard/auth/signin", umboard.core.http.getPost(signInGet, signInPost));
    try router.handle_func_unbound("/umboard/auth/signout", signOut);
}

fn signInGet(r: zap.Request) !void {
    try signInPage(r, .{ .error_message = null });
}

fn signInPost(r: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();

    try r.parseBody();
    r.parseQuery();

    const username = try r.getParamStr(arena.allocator(), "username") orelse {
        r.setStatus(.bad_request);
        try signInPage(r, .{ .error_message = "username is required" });
        return;
    };
    if (username.len == 0) {
        r.setStatus(.bad_request);
        try signInPage(r, .{ .error_message = "username is required" });
        return;
    }

    const password = try r.getParamStr(arena.allocator(), "password") orelse {
        r.setStatus(.bad_request);
        try signInPage(r, .{ .error_message = "password is required" });
        return;
    };
    if (password.len == 0) {
        r.setStatus(.bad_request);
        try signInPage(r, .{ .error_message = "password is required" });
        return;
    }

    const db = umboard.core.db.openBy(context) catch {
        r.setStatus(.internal_server_error);
        try r.sendBody("failed to open database");
        return;
    };
    defer umboard.core.db.close(db);

    const authenticated = utils.authenticate(context.allocator, db, username, password) catch |err| switch (err) {
        error.InvalidCredentials => {
            r.setStatus(.unauthorized);
            try signInPage(r, .{ .error_message = "Invalid username or password." });
            return;
        },
        else => {
            r.setStatus(.internal_server_error);
            try signInPage(r, .{ .error_message = "Authentication failed." });
            return;
        },
    };

    if (!authenticated) {
        r.setStatus(.unauthorized);
        try signInPage(r, .{ .error_message = "Invalid username or password." });
        return;
    }

    try utils.logIn(&r, context.allocator, db, username);
    try r.redirectTo("/umboard/main", null);
}

fn signOut(r: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();

    if (try r.getCookieStr(arena.allocator(), "session")) |session_key| {
        const db = umboard.core.db.openBy(context) catch {
            r.setStatus(.internal_server_error);
            try r.sendBody("failed to open database");
            return;
        };
        defer umboard.core.db.close(db);

        const dbc = umboard.core.db.c;
        const sql = "UPDATE auth_session SET revoked = 1 WHERE key = ?";

        var stmt: ?*dbc.sqlite3_stmt = null;
        if (dbc.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != dbc.SQLITE_OK) {
            r.setStatus(.internal_server_error);
            try r.sendBody("failed to prepare signout");
            return;
        }
        defer _ = dbc.sqlite3_finalize(stmt.?);

        if (dbc.sqlite3_bind_text(stmt.?, 1, session_key.ptr, @intCast(session_key.len), null) != dbc.SQLITE_OK) {
            r.setStatus(.internal_server_error);
            try r.sendBody("failed to bind session");
            return;
        }

        if (dbc.sqlite3_step(stmt.?) != dbc.SQLITE_DONE) {
            r.setStatus(.internal_server_error);
            try r.sendBody("failed to revoke session");
            return;
        }
    }

    try r.setCookie(.{
        .name = "session",
        .value = "invalid",
        .path = "/umboard",
        .max_age_s = -1,
        .http_only = true,
        .secure = false,
        .same_site = .Lax,
    });
    try r.redirectTo("/umboard/auth/signin", null);
}

fn signInPage(req: zap.Request, data: anytype) !void {
    var mustache = try zap.Mustache.fromData(signInTemplate);
    defer mustache.deinit();

    const rendered = mustache.build(data);
    defer rendered.deinit();

    try req.sendBody(rendered.str().?);
}
