const std = @import("std");

const FB_ENTRY = packed struct (u16) {
    character: u8,
    background: u4,
    foreground: u4,
};
const FRAMEBUFFER: [*]FB_ENTRY = @ptrFromInt(0xB8000);

export fn _start() noreturn {
    std.log.info("Hello, World!", .{});
    const FRAMEBUFFER_LEN = 80*25;
    for (FRAMEBUFFER[0..FRAMEBUFFER_LEN]) |*c| {
        c.* = @bitCast(@as(u16, 0xFFFF));
    }

    for ("Hello, World!", 0..) |c, i| {
        FRAMEBUFFER[i] = .{
            .foreground = 0xF,
            .background = 0x0,
            .character = c,
        };
    }

    while (true) {}
}

inline fn outb(comptime port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]\n\t"
        :
        : [val] "{al}" (val),
          [port] "N" (port),
    );
}
pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = myLogFn,
};


const debugPortWriter = std.io.GenericWriter(
    void,
    error{},
    debugPortWriteFn,
){.context = {}};

fn debugPortWriteFn(_: void, buffer: []const u8) error{}!usize {
    var count: usize = 0;
    for (buffer) |c| {
        outb(0xe9, c);
        count += 1;
    }
    return count;
}

pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype
) void {
    _ = scope;
    const level_str = switch (level) {
        .err => "err",
        .warn => "warn",
        .info => "info",
        .debug => "debug",
    };
    try debugPortWriter.print("[{s}] " ++ format ++ "\n", .{level_str} ++ args);
}

