const std = @import("std");
const umboard = @import("umboard");

pub const Context = struct {
    allocator: std.mem.Allocator,
    database_url: []const u8,

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{
            .allocator = allocator,
            .database_url = umboard.core.conf.settings.DATABASE_URL,
        };
    }
};
