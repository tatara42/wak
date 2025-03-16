const std = @import("std");
const builtin = @import("builtin");

const os = std.os;
const windows = os.windows;
const kernel32 = windows.kernel32;
const print = std.debug.print;
const exit = std.posix.exit;
const native_os = builtin.target.os.tag;
const heap = std.heap;

const keySize = u16;

const editorConfig = struct {
    cx: i16 = undefined,
    cy: i16 = undefined,
    screenrows: i16 = undefined,
    screencols: i16 = undefined,
    TIOCGWINSZ: u32 = undefined,
    Original_Input_Mode: windows.DWORD = undefined,
    Original_Output_Mode: windows.DWORD = undefined,
};

const editorKey = enum(keySize) {
    ARROW_LEFT = 1000,
    ARROW_DOWN,
    ARROW_UP,
    ARROW_RIGHT,
    PAGE_DOWN,
    PAGE_UP,
};

var E: editorConfig = undefined;

const Wak_Version = "0.0.1";

const mode = enum {
    insert,
    visual,
    normal,
};

var arena: heap.ArenaAllocator = undefined;
var abuf: std.ArrayList(u8) = undefined;

pub fn main() !void {

    // const stdout = std.io.getStdOut().writer();

    arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    abuf = std.ArrayList(u8).init(allocator);
    initEditor();
    // print("row:{} col:{}", .{ E.screenrows, E.screenrows });
    newline();
    enableRawMode();
    while (true) {
        editorRefreshScreen();
        editorProcessKeypress();
    }
    disableRawMode();
}

fn initEditor() void {
    E = switch (native_os) {
        .windows => editorConfig{
            .TIOCGWINSZ = 0x5413,
        },
        .linux => editorConfig{
            //To Do
        },
        else => editorConfig{},
    };
    E.cx = 0;
    E.cy = 0;
    if (getWindowSize(&E.screenrows, &E.screencols) == false) {
        die("getWindowSize");
    }
}

// Do you Like it Raw?
fn enableRawMode() void {
    switch (native_os) {
        .windows => {
            const H_INPUT = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse exit(1);
            const H_OUTPUT = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse exit(1);

            if (kernel32.GetConsoleMode(H_INPUT, &E.Original_Input_Mode) == 0) {
                die("Get Console Mode H_INPUT");
            }
            if (kernel32.GetConsoleMode(H_OUTPUT, &E.Original_Output_Mode) == 0) {
                die("Get Console Mode H_OUTPUT");
            }

            const ENABLE_ECHO_INPUT: windows.DWORD = 0x0004;
            const ENABLE_PROCESSED_INPUT: windows.DWORD = 0x0001;
            const ENABLE_LINE_INPUT: windows.DWORD = 0x0002;
            const ENABLE_VIRTUAL_TERMINAL_INPUT: windows.DWORD = 0x0200;

            const Raw_Input_Mode: windows.DWORD = E.Original_Input_Mode &
                ~ENABLE_LINE_INPUT &
                ~ENABLE_ECHO_INPUT &
                ~ENABLE_PROCESSED_INPUT | ENABLE_VIRTUAL_TERMINAL_INPUT;

            if (kernel32.SetConsoleMode(H_INPUT, Raw_Input_Mode) == 0) {
                die("Set Console Mode H_Input");
            }

            const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x0004;
            const Raw_Output_Mode: windows.DWORD = E.Original_Output_Mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING;

            if (kernel32.SetConsoleMode(H_OUTPUT, Raw_Output_Mode) == 0) {
                die("Set Console Mode H_OUTPUT");
            }
        },
        .linux => {
            //To Do
        },
        else => {},
    }
}

// Use Condom Prevent STIs
fn disableRawMode() void {
    // windows
    //
    switch (native_os) {
        .windows => {
            const H_INPUT = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) orelse exit(1);
            const H_OUTPUT = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse exit(1);

            if (kernel32.SetConsoleMode(H_INPUT, E.Original_Input_Mode) == 0) {
                die("Set Console Mode H_Input");
            }

            if (kernel32.SetConsoleMode(H_OUTPUT, E.Original_Output_Mode) == 0) {
                die("Set Console Mode H_OUTPUT");
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

fn editorRefreshScreen() void {

    // \x1b represents Escape Character ASCII 27
    // [ indicates Control Sequence (CSI)

    // Hide Cursor
    abuf.appendSlice("\x1b[?25l") catch die("Out of memory!");

    // 2J: 2 = Entire Screen, J = Erase in Display
    // try abuf.appendSlice("\x1b[2J");

    // H: equivalent 1;1H moves the cursor to row 1 and col 1
    abuf.appendSlice("\x1b[H") catch die("Out of memory!");

    editorDrawRows();

    // Move Cursor to the position stored
    const buf = std.fmt.allocPrint(heap.page_allocator, "\x1b[{};{}H", .{ E.cy, E.cx }) catch die("OutOfMemory!");

    abuf.appendSlice(buf) catch die("Out of memory!");

    // Display Cursor
    abuf.appendSlice("\x1b[?25h") catch die("Out of memory!");

    print("{s}", .{abuf.items});
}

// Draw Tilde ~
fn editorDrawRows() void {
    var i: u16 = 0;
    while (i < E.screenrows) : (i += 1) {
        if (i == @divTrunc(E.screenrows, 3)) {

            // Welcome to the rice field Mother Fucker
            const welcome = "Wak editor -- version" ++ Wak_Version;
            if (welcome.len > E.screencols) {
                abuf.appendSlice(welcome[0..@intCast(E.screencols)]) catch die("Out of memory!");
            } else {
                var padding: i16 = @divTrunc(E.screencols - @as(i16, @intCast(welcome.len)), 2);
                if (padding > 0) {
                    abuf.append('~') catch die("Out of memory!");
                    padding -= 1;
                }
                while (padding > 0) : (padding -= 1) {
                    abuf.append(' ') catch die("Out of memory!");
                }
                abuf.appendSlice(welcome) catch die("Out of memory!");
            }
        } else {
            abuf.append('~') catch die("Out of memory!");
        }

        abuf.appendSlice("\x1b[K") catch die("Out of memory!");

        if (i < E.screenrows - 1) {
            abuf.appendSlice("\r\n") catch die("Out of memory!");
        }
    }
}

fn editorProcessKeypress() void {
    const ch: keySize = editorReadKey();

    switch (ch) {
        @as(keySize, @intCast(ctrlKey('q'))) => {
            // Clear screen and return cursor to row1 col1
            print("\x1b[2J", .{});
            print("\x1b[H", .{});
            disableRawMode();
            exit(0);
        },

        @as(keySize, @intCast(ctrlKey('w'))) => {
            print("row:{} col:{}", .{ E.screenrows, E.screencols });
        },

        @intFromEnum(editorKey.ARROW_RIGHT), @intFromEnum(editorKey.ARROW_UP), @intFromEnum(editorKey.ARROW_DOWN), @intFromEnum(editorKey.ARROW_LEFT) => editorMoveCursor(ch),
        @intFromEnum(editorKey.PAGE_DOWN), @intFromEnum(editorKey.PAGE_UP) => {
            var count: i16 = E.screenrows;
            while (count > 0) : (count -= 1) {
                editorMoveCursor(if (ch == @intFromEnum(editorKey.PAGE_UP)) @intFromEnum(editorKey.ARROW_UP) else @intFromEnum(editorKey.ARROW_DOWN));
            }
        },

        else => {
            if (std.ascii.isControl(@intCast(ch))) {
                print("{d} ", .{ch});
            } else {
                print("{d}:{u} ", .{ ch, ch });
            }
        },
    }
}

fn editorReadKey() keySize {
    const stdin = std.io.getStdIn().reader();
    var buf: [4]u8 = undefined;
    _ = stdin.read(buf[0..]) catch die("read");
    if (buf[0] == '\x1b') {
        if (buf[1] == '[') {
            if (buf[2] >= '0' and buf[2] <= '9') {
                if (buf[3] == '~') {
                    switch (buf[2]) {
                        '5' => return @intFromEnum(editorKey.PAGE_UP),
                        '6' => return @intFromEnum(editorKey.PAGE_DOWN),
                        else => {},
                    }
                }
            } else {
                switch (buf[2]) {
                    'A' => return @intFromEnum(editorKey.ARROW_UP),
                    'B' => return @intFromEnum(editorKey.ARROW_DOWN),
                    'C' => return @intFromEnum(editorKey.ARROW_RIGHT),
                    'D' => return @intFromEnum(editorKey.ARROW_LEFT),
                    else => {},
                }
            }
        }

        return '\x1b';
    } else {
        return buf[0];
    }
    return buf[0];
}

fn editorMoveCursor(key: keySize) void {
    switch (key) {
        @intFromEnum(editorKey.ARROW_LEFT) => {
            if (E.cx != 0)
                E.cx -= 1;
        },
        @intFromEnum(editorKey.ARROW_RIGHT) => {
            if (E.cx != E.screencols)
                E.cx += 1;
        },
        @intFromEnum(editorKey.ARROW_UP) => {
            if (E.cy != 0)
                E.cy -= 1;
        },
        @intFromEnum(editorKey.ARROW_DOWN) => {
            if (E.cy != E.screenrows)
                E.cy += 1;
        },
        else => {},
    }
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
            if (kernel32.GetConsoleScreenBufferInfo(H_Output, &csbi) == 0 or csbi.srWindow.Right <= 0) {
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
fn die(er: [:0]const u8) noreturn {
    std.debug.print("\x1b[2J", .{});
    std.debug.print("\x1b[H", .{});
    disableRawMode();
    pError(er);
}

fn pError(errMessage: [:0]const u8) noreturn {
    std.debug.print("Error:{s}\n", .{errMessage});
    exit(1);
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
