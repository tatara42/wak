const std = @import("std");
const os = std.os;
const windows = os.windows;
const kernel32 = windows.kernel32;
const posix = std.posix;
const exit = posix.exit;
const heap = std.heap;

var Original_Input_Mode: windows.DWORD = undefined;
var Original_Output_Mode: windows.DWORD = undefined;

var buffer: std.ArrayList(u8) = undefined;

pub fn main() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    buffer = std.ArrayList(u8).init(allocator);
    enableRawMode();
    defer disableRawMode();
    while (true) {
        editorProcessReadkey();
        editorDraw();
    }
}

fn editorDraw() void {
    std.debug.print("{s}", .{buffer.items});
    newline();
}

fn newline() void {
    std.debug.print("\n", .{});
}

fn editorProcessReadkey() void {
    const ch = editorReadkey();
    switch (ch) {
        @as(u8, @intCast('q')) => exit(0),
        @as(u8, @intCast(ctrlKey('q'))) => exit(0),
        else => {
            buffer.append(ch) catch pError("Out of memory!");
        },
    }
}

fn pError(errMessage: [:0]const u8) void {
    std.debug.print("{s}", .{errMessage[0..]});
    disableRawMode();
    exit(1);
}

fn editorReadkey() u8 {
    var buf: [3]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    _ = stdin.read(buf[0..]) catch exit(1);
    if (buf[0] == ctrlKey('q')) {
        disableRawMode();
        exit(0);
    } else if (buf[0] == '\x1b') {
        return buf[2];
    } else {
        return buf[0];
    }
}

fn ctrlKey(char: u8) u8 {
    return char & 0x1f;
}

fn enableRawMode() void {
    const H_INPUT = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse exit(0);
    const H_OUTPUT = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse exit(0);

    if (kernel32.GetConsoleMode(H_INPUT, &Original_Input_Mode) == 0) {
        exit(1);
    }

    if (kernel32.GetConsoleMode(H_OUTPUT, &Original_Output_Mode) == 0) {
        exit(1);
    }

    const ENABLE_ECHO_INPUT: windows.DWORD = 0x0004;
    const ENABLE_PROCESSED_INPUT: windows.DWORD = 0x0001;
    const ENABLE_LINE_INPUT: windows.DWORD = 0x0002;
    const ENABLE_VIRTUAL_TERMINAL_INPUT: windows.DWORD = 0x0200;

    const Raw_Input_Mode: windows.DWORD = Original_Input_Mode &
        ~ENABLE_LINE_INPUT &
        ~ENABLE_ECHO_INPUT &
        ~ENABLE_PROCESSED_INPUT | ENABLE_VIRTUAL_TERMINAL_INPUT;

    std.debug.print("Raw_Input_Mode:{}", .{Raw_Input_Mode});
    newline();

    if (kernel32.SetConsoleMode(H_INPUT, Raw_Input_Mode) == 0) {
        exit(1);
    }

    const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x0004;
    const Raw_Output_Mode: windows.DWORD = Original_Output_Mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING;

    std.debug.print("Raw_Output_Mode:{}", .{Raw_Output_Mode});
    newline();

    if (kernel32.SetConsoleMode(H_OUTPUT, Raw_Output_Mode) == 0) {
        exit(1);
    }

    std.debug.print("Raw Mode Enable", .{});
    newline();
}

fn disableRawMode() void {
    const H_INPUT = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse exit(0);
    const H_OUTPUT = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse exit(0);

    if (kernel32.SetConsoleMode(H_OUTPUT, Original_Output_Mode) == 0) {
        exit(1);
    }

    if (kernel32.SetConsoleMode(H_INPUT, Original_Input_Mode) == 0) {
        exit(1);
    }

    std.debug.print("Raw Mode Disable\n", .{});
}
