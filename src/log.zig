const std = @import("std");

const LogType = enum(u1) { ERROR, INFO };
pub const ParserError = error { InvalidInstruction, UnexpectedEOF };
pub const RuntimeError = error { CallStackError, DivisionByZero, StackError, InputError, LabelError };

// TODO : Improve error messages
pub fn print(message: []const u8, log_type: LogType) !void {
    var stderr_buffer: [64]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    switch (log_type) {
        .ERROR => try stderr.print("\x1b[31merror\x1b[0m: error.{s}\n", .{ message }),
        else => try stderr.print("\x1b[34minfo\x1b[0m: {s}\n", .{ message })
    }
    try stderr.flush();
}
