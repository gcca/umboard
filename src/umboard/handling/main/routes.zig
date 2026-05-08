const std = @import("std");
const zap = @import("zap");
const umboard = @import("umboard");

const utils = @import("utils.zig");

pub fn register(router: *zap.Router, context: *umboard.core.context.Context) !void {
    try umboard.core.http.Middleware(.{
        umboard.handling.auth.middlewares.LogInRequired(),
    }, mainGet).register(router, "/umboard/main", context);
}

fn mainGet(r: zap.Request, s: umboard.core.http.Scope) !void {
    var arena = std.heap.ArenaAllocator.init(s.context.allocator);
    defer arena.deinit();

    const session_key = umboard.helpers.keyOfSession(arena.allocator(), r);
    defer arena.allocator().free(session_key);

    const role = try utils.roleForSession(s, session_key);
    defer s.context.allocator.free(role);

    const path = try std.fmt.allocPrint(s.context.allocator, "/umboard/{s}", .{role});
    defer s.context.allocator.free(path);

    try r.redirectTo(path, null);
}
