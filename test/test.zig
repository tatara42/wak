const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var arrayList = std.ArrayList(u8).init(allocator);

    try arrayList.append('c');
    try arrayList.append('c');

    std.debug.print("{s}", .{arrayList.items});
}
