const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const windows = os.windows;
const Kernel32 = windows.kernel32;
const print = std.debug.print;

const native_os = builtin.target.os.tag;

const editorConfig = struct {
    screenrows: i16 = undefined,
    screencols: i16 = undefined,
    TIOCGWINSZ: u32 = undefined,
    Original_Input_Mode: windows.DWORD = undefined,
};

var E: editorConfig = undefined;

const Wak_Version = "0.0.1";

const mode = enum {
    insert,
    visual,
    normal,
};

var arena: std.heap.ArenaAllocator = undefined;
var abuf: std.ArrayList(u8) = undefined;

pub fn main() !void {

    // const stdout = std.io.getStdOut().writer();

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    abuf = std.ArrayList(u8).init(allocator);
    init();
    print("row:{} col:{}", .{ E.screenrows, E.screenrows });
    newline();
    try enableRawMode();
    while (true) {
        try editorRefreshScreen();
        try editorProcessKeypress();
    }
    try disableRawMode();
}

fn init() void {
    E = switch (native_os) {
        .windows => editorConfig{
            .TIOCGWINSZ = 0x5413,
        },
        .linux => editorConfig{
            //To Do
        },
        else => editorConfig{},
    };
    if (getWindowSize(&E.screenrows, &E.screencols) == false) {
        die("getWindowSize");
    }
}

// Do you Like it Raw?
fn enableRawMode() !void {
    switch (native_os) {
        .windows => {
            const H_Input = try windows.GetStdHandle(windows.STD_INPUT_HANDLE);

            if (Kernel32.GetConsoleMode(H_Input, &E.Original_Input_Mode) == 0) {
                die("Get Console Mode");
            }

            const Raw_Input_Mode: windows.DWORD = 0;
            if (Kernel32.SetConsoleMode(H_Input, Raw_Input_Mode) == 0) {
                die("Set Console Mode");
            }
        },
        .linux => {
            //To Do
        },
        else => {},
    }
}

// Use Condom Prevent STIs
fn disableRawMode() !void {
    // windows
    //
    switch (native_os) {
        .windows => {
            const H_Input = try windows.GetStdHandle(windows.STD_INPUT_HANDLE);
            if (Kernel32.SetConsoleMode(H_Input, E.Original_Input_Mode) == 0) {
                die("Set Console Mode");
            }
        },
        .linux => {
            //To Do
        },

        else => {
            //To Do
        },
    }
}

fn editorRefreshScreen() !void {

    // \x1b represents Escape Character ASCII 27
    // [ indicates Control Sequence (CSI)

    // Hide Cursor
    try abuf.appendSlice("\x1b[?25l");

    // 2J: 2 = Entire Screen, J = Erase in Display
    // try abuf.appendSlice("\x1b[2J");

    // H: equivalent 1;1H moves the cursor to row 1 and col 1
    try abuf.appendSlice("\x1b[H");

    try editorDrawRows();

    // Move Cursor to row 1 col 1
    try abuf.appendSlice("\x1b[H");

    // Display Cursor
    try abuf.appendSlice("\x1b[?25h");

    print("{s}", .{abuf.items});
}

// Draw Tilde ~
fn editorDrawRows() !void {
    var i: u16 = 0;
    while (i < E.screenrows) : (i += 1) {
        if (i == @divTrunc(E.screenrows, 3)) {

            // Welcome to the rice field Mother Fucker
            const welcome = "Wak editor -- version" ++ Wak_Version;
            if (welcome.len > E.screencols) {
                try abuf.appendSlice(welcome[0..@intCast(E.screencols)]);
            } else {
                var padding: i16 = @divTrunc(E.screencols - @as(i16, @intCast(welcome.len)), 2);
                if (padding > 0) {
                    try abuf.append('~');
                    padding -= 1;
                }
                while (padding > 0) : (padding -= 1) {
                    try abuf.append(' ');
                }
                try abuf.appendSlice(welcome);
            }
        } else {
            try abuf.append('~');
        }

        try abuf.appendSlice("\x1b[K");

        if (i < E.screenrows - 1) {
            try abuf.appendSlice("\r\n");
        }
    }
}

fn editorProcessKeypress() !void {
    const ch: u8 = try editorReadKey();

    // inline switch (ch) {
    //     ctrlKey('q') => die("CTRLQ"),
    //     std.ascii.isControl(ch) => print("{b} ", .{ch}),
    //     else => print("{b}:{u} ", .{ ch, ch }),
    // }

    if (ch == ctrlKey('q')) {
        std.debug.print("\x1b[2J", .{});
        std.debug.print("\x1b[H", .{});
        std.posix.exit(0);
    } else if (ch == ctrlKey('w')) {
        print("row:{} col:{}", .{ E.screenrows, E.screencols });
    } else if (std.ascii.isControl(ch)) {
        print("{d} ", .{ch});
    } else {
        print("{u}", .{ch});
    }
}

fn editorReadKey() !u8 {
    const stdin = std.io.getStdIn().reader();
    var buf: [1]u8 = undefined;
    _ = try stdin.read(&buf);
    return buf[0];
}

fn appendBuf(ab: *abuf, ch: *const u8, len: usize) void {
    _ = ab;
    _ = ch;
    _ = len;
}

fn ctrlKey(key: u8) u8 {
    return key & 0x1f;
}

test "getWindowSize" {
    const exRow: i16 = 168;
    const exCol: i16 = 14;

    var acRow: i16 = undefined;
    var acCol: i16 = undefined;

    const success = getWindowSize(&acRow, &acCol);
    try std.testing.expect(success);
    try std.testing.expectEqual(exRow, acRow);
    try std.testing.expectEqual(exCol, acCol);
}

fn getWindowSize(row: *i16, col: *i16) bool {
    switch (native_os) {
        .windows => {
            const H_Output = windows.GetStdHandle(windows.STD_OUTPUT_HANDLE) catch return false;
            var csbi: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            if (Kernel32.GetConsoleScreenBufferInfo(H_Output, &csbi) == 0 or csbi.srWindow.Right <= 0) {
                // print("{}", .{csbi});

                // [999C: Cursor Forward
                // [999B: Cursor Down
                const bytes_written = std.io.getStdOut().writer().write("\x1b[999C\x1b[999B") catch return false;
                if (bytes_written != 12) {
                    return false;
                }

                return getCursorPosition(row, col);
            }
            row.* = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
            col.* = csbi.srWindow.Right - csbi.srWindow.Left + 1;
            // print("row:{} col:{}", .{ row.*, col.* });
            return true;
        },

        .linux => {
            //To Do
            return false;
        },

        else => {
            return false;
        },
    }
}

fn getCursorPosition(row: *i16, col: *i16) bool {
    // Send the ANSI escape sequence to query the cursor position
    const stdout = std.io.getStdOut().writer();
    stdout.writeAll("\x1b[6n") catch return false;

    var buf: [32]u8 = undefined;
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        const stdin = std.io.getStdIn();
        const bytes_read = stdin.read(buf[i .. i + 1]) catch return false;
        if (bytes_read != 1) {
            return false;
        }
        if (buf[i] == 'R') {
            break;
        }
    }

    if (i < 2 or buf[0] != '\x1b' or buf[1] != '[') {
        return false;
    }

    const response = buf[2..i]; // Skip the leading "\x1b["
    var it = std.mem.splitAny(u8, response, ";");
    const row_str = it.next() orelse return false;
    const col_str = it.next() orelse return false;

    row.* = std.fmt.parseInt(i16, row_str, 10) catch return false;
    col.* = std.fmt.parseInt(i16, col_str, 10) catch return false;

    return true;
}

fn newline() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("\n", .{}) catch return;
}

fn insertMode() !void {}

fn visualMode() !void {}

// Kill this bitch with some salt
fn die(er: [:0]const u8) void {
    std.debug.print("\x1b[2J", .{});
    std.debug.print("\x1b[H", .{});

    pError(er);
    std.posix.exit(1);
}

fn pError(errMessage: [:0]const u8) void {
    std.debug.print("Error:{s}\n", .{errMessage});
}

fn printOS() void {
    const targetOS = switch (native_os) {
        .windows => "Windows",
        .linux => "Linux",
        .macos => "MacOS",
        else => "Unknown Os",
    };

    std.debug.print("Running on {s}", .{targetOS});
    newline();
}
