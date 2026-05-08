const std = @import("std");
const zap = @import("zap");
const umboard = @import("umboard");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.log.warn("Memory leak detected!", .{});
        }
    }
    const allocator = gpa.allocator();

    try umboard.core.conf.init(allocator);
    defer umboard.core.conf.deinit(allocator);

    var context = umboard.core.context.Context.init(allocator);

    var router = zap.Router.init(allocator, .{});
    defer router.deinit();

    try router.handle_func_unbound("/", indexHandler);
    try router.handle_func_unbound("/umboard", indexHandler);
    try router.handle_func_unbound("/healthcheck", healthHandler);

    try umboard.handling.auth.routes.register(&router, &context);
    try umboard.handling.main.routes.register(&router, &context);
    try umboard.handling.admin.routes.register(&router, &context);
    try umboard.handling.root.routes.register(&router, &context);

    var listener = zap.HttpListener.init(.{
        .interface = "0.0.0.0",
        .port = 5561,
        .on_request = router.on_request_handler(),
    });

    std.debug.print("Listening on 0.0.0.0:5561\n", .{});

    try listener.listen();

    zap.start(.{ .threads = 2, .workers = 1 });
}

fn indexHandler(r: zap.Request) !void {
    try r.redirectTo("/umboard/auth/signin", null);
}

fn healthHandler(r: zap.Request) !void {
    try r.sendBody("🙇");
}
