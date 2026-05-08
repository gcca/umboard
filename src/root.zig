pub const core = struct {
    pub const http = @import("umboard/core/http.zig");
    pub const conf = @import("umboard/core/conf.zig");
    pub const db = @import("umboard/core/db.zig");
    pub const context = @import("umboard/core/context.zig");
};

pub const shortcuts = @import("umboard/shortcuts.zig");
pub const helpers = @import("umboard/helpers.zig");
pub const utils = @import("umboard/utils.zig");

pub const handling = struct {
    pub const auth = struct {
        pub const middlewares = @import("umboard/handling/auth/middlewares.zig");
        pub const routes = @import("umboard/handling/auth/routes.zig");
        pub const securing = @import("umboard/handling/auth/securing.zig");
    };
    pub const admin = struct {
        pub const routes = @import("umboard/handling/admin/routes.zig");
    };
    pub const root = struct {
        pub const routes = @import("umboard/handling/root/routes.zig");
        pub const utils = @import("umboard/handling/root/utils.zig");
    };
    pub const main = struct {
        pub const routes = @import("umboard/handling/main/routes.zig");
    };
};
