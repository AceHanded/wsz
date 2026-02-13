const std = @import("std");
const Instruction = @import("parser.zig").Instruction;
const RuntimeError = @import("log.zig").RuntimeError;

pub const VM = struct {
    instructions: []Instruction,
    allocator: std.mem.Allocator,
    ip: usize,
    stack: std.ArrayList(i64),
    heap: std.AutoHashMap(i64, i64),
    call_stack: std.ArrayList(usize),
    labels: std.AutoHashMap(i64, usize),

    /// Prints a single ASCII character, or signed 64-bit integer to stdout.
    fn print(val: i64, ascii: bool) !void {
        var stdout_buffer: [20]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;

        if (ascii) {
            try stdout.print("{c}", .{ @as(u8, @intCast(val & 0xff)) });  // Mask value to 8 bits
        } else {
            try stdout.print("{d}", .{ val });
        }
        try stdout.flush();
    }

    /// Initializes a `VM` instance for the given instruction stream.
    pub fn init(instructions: []Instruction, allocator: std.mem.Allocator) !VM {
        const stack = try std.ArrayList(i64).initCapacity(allocator, 64);
        const call_stack = try std.ArrayList(usize).initCapacity(allocator, 16);
        const heap = std.AutoHashMap(i64, i64).init(allocator);
        var labels = std.AutoHashMap(i64, usize).init(allocator);

        for (instructions, 0..) |instruction, idx| {
            switch (instruction) {
                .LABEL => |label| try labels.put(label, idx),
                else => {}
            }
        }
        return VM{ .instructions = instructions, .allocator = allocator, .ip = 0, .stack = stack, .heap = heap, .call_stack = call_stack, .labels = labels };
    }

    /// Executes the instruction stream.
    pub fn run(self: *VM) !void {
        while (self.ip < self.instructions.len) : (self.ip += 1) {
            const instruction: Instruction = self.instructions[self.ip];

            switch (instruction) {
                .PUSH => |num| try self.stack.append(self.allocator, num),
                .DUP => { 
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    try self.stack.append(self.allocator, self.stack.items[self.stack.items.len - 1]);
                },
                .SWAP => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    std.mem.swap(i64, &self.stack.items[self.stack.items.len - 1], &self.stack.items[self.stack.items.len - 2]);
                },
                .DROP => {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    _ = self.stack.pop();
                },
                .COPY => |num| {
                    if (num < 0) return RuntimeError.StackError;

                    const ridx: usize = @as(usize, @intCast(num));
                    if (ridx >= self.stack.items.len) return RuntimeError.StackError;

                    try self.stack.append(self.allocator, self.stack.items[self.stack.items.len - 1 - ridx]);
                },
                .SLIDE => |num| {
                    if (num < 0) return RuntimeError.StackError;

                    const n: usize = @as(usize, @intCast(num));
                    if (self.stack.items.len == 0 or n > self.stack.items.len - 1) return RuntimeError.StackError;

                    const top: i64 = self.stack.pop().?;

                    for (0..n) |_| {
                        _ = self.stack.pop();
                    }
                    try self.stack.append(self.allocator, top);
                },
                .ADD => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    const right: i64 = self.stack.pop().?;
                    const left: i64 = self.stack.pop().?;
                    try self.stack.append(self.allocator, left + right);
                },
                .SUB => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    const right: i64 = self.stack.pop().?;
                    const left: i64 = self.stack.pop().?;
                    try self.stack.append(self.allocator, left - right);
                },
                .MUL => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    const right: i64 = self.stack.pop().?;
                    const left: i64 = self.stack.pop().?;
                    try self.stack.append(self.allocator, left * right);
                },
                .DIV => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    const right: i64 = self.stack.pop().?;
                    if (right == 0) return RuntimeError.DivisionByZero;

                    const left: i64 = self.stack.pop().?;
                    try self.stack.append(self.allocator, @divTrunc(left, right));
                },
                .MOD => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    const right: i64 = self.stack.pop().?;
                    if (right == 0) return RuntimeError.DivisionByZero;

                    const left: i64 = self.stack.pop().?;
                    try self.stack.append(self.allocator, @rem(left, right));
                },
                .READC => {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    var stdin_buffer: [1]u8 = undefined;
                    const bytes_read: usize = try std.fs.File.stdin().read(&stdin_buffer);
                    const value: i64 = if (bytes_read == 0) 0 else stdin_buffer[0];  // 0 on EOF

                    try self.heap.put(self.stack.pop().?, value);
                },
                .READI => {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    var stdin_buffer: [20]u8 = undefined;
                    const bytes_read: usize = try std.fs.File.stdin().read(&stdin_buffer);
                    if (bytes_read == 0) return RuntimeError.InputError;

                    const slice: []const u8 = std.mem.trim(u8, stdin_buffer[0..bytes_read], " \n\r\t");
                    const value: i64 = try std.fmt.parseInt(i64, slice, 10);
                    try self.heap.put(self.stack.pop().?, value);
                },
                .PRINTC => {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    try print(self.stack.pop().?, true);
                },
                .PRINTI => {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;
                    
                    try print(self.stack.pop().?, false);
                },
                .STORE => {
                    if (self.stack.items.len < 2) return RuntimeError.StackError;

                    const value: i64 = self.stack.pop().?;
                    const address: i64 = self.stack.pop().?;
                    try self.heap.put(address, value);
                },
                .RETRIEVE => {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    const value: i64 = self.heap.get(self.stack.pop().?) orelse 0;  //0 if address is not found
                    try self.stack.append(self.allocator, value);
                },
                .LABEL => |_| {},  // No runtime op
                .CALL => |label| {
                    const target: usize = self.labels.get(label) orelse return RuntimeError.LabelError;
                    try self.call_stack.append(self.allocator, self.ip);
                    self.ip = target;
                    continue;
                },
                .JMP => |label| {
                    const target: usize = self.labels.get(label) orelse return RuntimeError.LabelError;
                    self.ip = target;
                    continue;
                },
                .JZ => |label| {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    if (self.stack.pop().? == 0) {
                        const target: usize = self.labels.get(label) orelse return RuntimeError.LabelError;
                        self.ip = target;
                        continue;
                    }
                },
                .JN => |label| {
                    if (self.stack.items.len == 0) return RuntimeError.StackError;

                    if (self.stack.pop().? < 0) {
                        const target: usize = self.labels.get(label) orelse return RuntimeError.LabelError;
                        self.ip = target;
                        continue;
                    }
                },
                .RET => {
                    if (self.call_stack.items.len == 0) return RuntimeError.CallStackError;

                    self.ip = self.call_stack.pop().?;
                    continue;
                },
                else => break  // .END
            }
        }
    }
};
