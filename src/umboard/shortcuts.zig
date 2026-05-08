const zap = @import("zap");
const umboard = @import("umboard");

pub fn render(req: zap.Request, template: []const u8) !void {
    try renderWith(req, template, .{});
}

pub fn renderWith(req: zap.Request, template: []const u8, data: anytype) !void {
    var mustache = try zap.Mustache.fromData(template);
    defer mustache.deinit();

    const rendered = mustache.build(data);
    defer rendered.deinit();

    try req.sendBody(rendered.str().?);
}

pub fn RoleRoute(comptime role: []const u8, comptime handler: anytype) type {
    return umboard.core.http.Middleware(.{
        umboard.handling.auth.middlewares.LogInRequired(),
        umboard.handling.auth.middlewares.RoleRequired(role),
    }, handler);
}
