const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const Windows = os.windows;
const Kernel32 = Windows.kernel32;
const print = std.debug.print;

const native_os = builtin.target.os.tag;

const editorConfig = struct {
    screenrows: i16 = undefined,
    screencols: i16 = undefined,
    TIOCGWINSZ: u32 = undefined,
    Original_Input_Mode: Windows.DWORD = undefined,
};

var E: editorConfig = undefined;

const mode = enum {
    insert,
    visual,
    normal,
};

pub fn main() !void {
    // const stdout = std.io.getStdOut().writer();

    init();
    try enableRawMode();
    while (true) {
        // editorRefreshScreen();
        try editorProcessKeypress();
    }
    try disableRawMode();
}

fn editorRefreshScreen() void {

    // \x1b represents Escape Character ASCII 27
    // [ indicates Control Sequence (CSI)
    // 2J: 2 = Entire Screen, J = Erase in Display
    std.debug.print("\x1b[2J", .{});

    // H: equivalent 1;1H moves the cursor to row 1 and col 1
    std.debug.print("\x1b[H", .{});

    editorDrawRows();

    std.debug.print("\x1b[H", .{});
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
        print("{d}:{u} ", .{ ch, ch });
    }
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
    const H_Output = Windows.GetStdHandle(Windows.STD_OUTPUT_HANDLE) catch return false;
    var csbi: Windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (Kernel32.GetConsoleScreenBufferInfo(H_Output, &csbi) == 0) {
        return false;
    }
    row.* = csbi.srWindow.Right - csbi.srWindow.Left + 1;
    col.* = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;
    return true;
}

fn editorReadKey() !u8 {
    const stdin = std.io.getStdIn().reader();
    var buf: [1]u8 = undefined;
    _ = try stdin.read(&buf);
    return buf[0];
}

fn ctrlKey(key: u8) u8 {
    return key & 0x1f;
}

fn newline() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n", .{});
}

fn insertMode() !void {}

fn visualMode() !void {}

fn editorDrawRows() void {
    var i: u16 = 0;
    while (i < E.screenrows) : (i += 1) {
        print("~\r\n", .{});
    }
}

// Do you Like it Raw?
fn enableRawMode() !void {

    // Windows
    if (native_os == std.Target.Os.Tag.windows) {
        const H_Input = try Windows.GetStdHandle(Windows.STD_INPUT_HANDLE);

        if (Kernel32.GetConsoleMode(H_Input, &E.Original_Input_Mode) == 0) {
            die("Get Console Mode");
        }

        const Raw_Input_Mode: Windows.DWORD = 0;
        if (Kernel32.SetConsoleMode(H_Input, Raw_Input_Mode) == 0) {
            die("Set Console Mode");
        }
    }
}

// Use Condom Prevent STIs
fn disableRawMode() !void {
    // Windows
    if (native_os == std.Target.Os.Tag.windows) {
        const H_Input = try Windows.GetStdHandle(Windows.STD_INPUT_HANDLE);
        if (Kernel32.SetConsoleMode(H_Input, E.Original_Input_Mode) == 0) {
            die("Set Console Mode");
        }
    }
}

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

fn init() void {
    E = switch (native_os) {
        .windows => editorConfig{
            .TIOCGWINSZ = 0x5413,
        },
        else => editorConfig{},
    };
    if (getWindowSize(&E.screenrows, &E.screencols) == false) {
        die("getWindowSize");
    }
}

fn printOS() !void {
    const targetOS = switch (native_os) {
        .windows => "Windows",
        .linux => "Linux",
        .macos => "MacOS",
        else => "Unknown Os",
    };

    std.debug.print("Running on {s}", .{targetOS});
    try newline();
}
