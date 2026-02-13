const std = @import("std");
const Token = @import("lexer.zig").Token;
const ParserError = @import("log.zig").ParserError;

pub const InstructionType = enum(u5) { PUSH, DUP, SWAP, DROP, COPY, SLIDE, ADD, SUB, MUL, DIV, MOD, READC, READI,
                                       PRINTC, PRINTI, STORE, RETRIEVE, LABEL, CALL, JMP, JZ, JN, RET, END };

pub const Instruction = union(InstructionType) {
    // Stack
    PUSH: i64,
    DUP,
    SWAP,
    DROP,
    COPY: i64,
    SLIDE: i64,
    // Arithmetic
    ADD,
    SUB,
    MUL,
    DIV,
    MOD,
    // I/O
    READC,
    READI,
    PRINTC,
    PRINTI,
    // Heap
    STORE,
    RETRIEVE,
    // Flow
    LABEL: i64,
    CALL: i64,
    JMP: i64,
    JZ: i64,
    JN: i64,
    RET,
    END,

    /// Prints a formatted `Instruction` to stdout.
    pub fn print(self: *const Instruction) void {
        switch (self.*) {
            .PUSH => |v| std.debug.print("PUSH {}\n", .{v}),
            .DUP => std.debug.print("DUP\n", .{}),
            .SWAP => std.debug.print("SWAP\n", .{}),
            .DROP => std.debug.print("DROP\n", .{}),
            .COPY => |v| std.debug.print("COPY {}\n", .{v}),
            .SLIDE => |v| std.debug.print("SLIDE {}\n", .{v}),
            .ADD => std.debug.print("ADD\n", .{}),
            .SUB => std.debug.print("SUB\n", .{}),
            .MUL => std.debug.print("MUL\n", .{}),
            .DIV => std.debug.print("DIV\n", .{}),
            .MOD => std.debug.print("MOD\n", .{}),
            .READC => std.debug.print("READC\n", .{}),
            .READI => std.debug.print("READI\n", .{}),
            .PRINTC => std.debug.print("PRINTC\n", .{}),
            .PRINTI => std.debug.print("PRINTI\n", .{}),
            .STORE => std.debug.print("STORE\n", .{}),
            .RETRIEVE => std.debug.print("RETRIEVE\n", .{}),
            .LABEL => |v| std.debug.print("LABEL {}\n", .{v}),
            .CALL  => |v| std.debug.print("CALL {}\n", .{v}),
            .JMP   => |v| std.debug.print("JMP {}\n", .{v}),
            .JZ    => |v| std.debug.print("JZ {}\n", .{v}),
            .JN   => |v| std.debug.print("JN {}\n", .{v}),
            .RET => std.debug.print("RET\n", .{}),
            .END => std.debug.print("END\n", .{})
        }
    }
};

pub const Parser = struct {
    tokens: []Token,
    allocator: std.mem.Allocator,
    idx: usize,

    /// Parses a signed binary integer.
    fn parseNumber(self: *Parser) !i64 {
        const sign_token: Token = self.next() orelse return ParserError.UnexpectedEOF;

        const sign: i2 = switch (sign_token.type) {
            .SPACE => 1,
            .TAB => -1,
            else => return ParserError.InvalidInstruction
        };
        var value: i64 = 0;

        while (self.next()) |token| {
            switch (token.type) {
                .SPACE => value = (value << 1),
                .TAB => value = (value << 1) | 1,
                else => break
            }
        }
        return sign * value;
    }

    /// Parses a binary label identifier.
    fn parseLabel(self: *Parser) !i64 {
        var value: i64 = 0;

        while (self.next()) |token| {
            switch (token.type) {
                .SPACE => value = (value << 1),
                .TAB => value = (value << 1) | 1,
                else => break
            }
        }
        return value;
    }

    /// Parses a stack manipulation operation.
    fn parseStack(self: *Parser) !Instruction {
        const first: Token = self.next() orelse return ParserError.UnexpectedEOF;

        switch (first.type) {
            .SPACE => {
                const num: i64 = try self.parseNumber();
                return Instruction{ .PUSH = num };
            },
            .TAB => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => {
                        const num: i64 = try self.parseNumber();
                        return Instruction{ .COPY = num };
                    },
                    .TAB => return ParserError.InvalidInstruction,
                    else => {
                        const num: i64 = try self.parseNumber();
                        return Instruction{ .SLIDE = num };
                    }
                }
            },
            else => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return .DUP,
                    .TAB => return .SWAP,
                    else => return .DROP
                }
            }
        }
    }

    /// Parses an arithmetic operation.
    fn parseArithmetic(self: *Parser) !Instruction {
        const first: Token = self.next() orelse return ParserError.UnexpectedEOF;

        switch (first.type) {
            .SPACE => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return .ADD,
                    .TAB => return .SUB,
                    else => return .MUL
                }
            },
            .TAB => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return .DIV,
                    .TAB => return .MOD,
                    else => return ParserError.InvalidInstruction
                }
            },
            else => return ParserError.InvalidInstruction
        }
    }

    /// Parses an I/O operation.
    fn parseIO(self: *Parser) !Instruction {
        const first: Token = self.next() orelse return ParserError.UnexpectedEOF;

        switch (first.type) {
            .SPACE => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return .PRINTC,
                    .TAB => return .PRINTI,
                    else => return ParserError.InvalidInstruction
                }
            },
            .TAB => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return .READC,
                    .TAB => return .READI,
                    else => return ParserError.InvalidInstruction
                }
            },
            else => return ParserError.InvalidInstruction
        }
    }

    /// Parses a heap access operation.
    fn parseHeap(self: *Parser) !Instruction {
        const first: Token = self.next() orelse return ParserError.UnexpectedEOF;

        switch (first.type) {
            .SPACE => return .STORE,
            .TAB => return .RETRIEVE,
            else => return ParserError.InvalidInstruction
        }
    }

    /// Parses a flow control operation.
    fn parseFlow(self: *Parser) !Instruction {
        const first: Token = self.next() orelse return ParserError.UnexpectedEOF;

        switch (first.type) {
            .SPACE => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => {
                        const label: i64 = try self.parseLabel();
                        return Instruction{ .LABEL = label };
                    },
                    .TAB => {
                        const label: i64 = try self.parseLabel();
                        return Instruction{ .CALL = label };
                    },
                    else => {
                        const label: i64 = try self.parseLabel();
                        return Instruction{ .JMP = label };
                    }
                }
            },
            .TAB => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => {
                        const label: i64 = try self.parseLabel();
                        return Instruction{ .JZ = label };
                    },
                    .TAB => {
                        const label: i64 = try self.parseLabel();
                        return Instruction{ .JN = label };
                    },
                    else => return .RET
                }
            },
            else => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return ParserError.InvalidInstruction,
                    .TAB => return ParserError.InvalidInstruction,
                    else => return .END
                }
            }
        }
    }

    /// Parses a single instruction based on the Instruction Modification Parameter (IMP).
    fn parseInstruction(self: *Parser) !Instruction {
        const first: Token = self.next() orelse return ParserError.UnexpectedEOF;

        switch (first.type) {
            .SPACE => return self.parseStack(),
            .TAB => {
                const second: Token = self.next() orelse return ParserError.UnexpectedEOF;

                switch (second.type) {
                    .SPACE => return self.parseArithmetic(),
                    .TAB => return self.parseHeap(),
                    else => return self.parseIO()
                }
            },
            else => return self.parseFlow()
        }
    }

    /// Returns the current token and advances the parsing index.
    fn next(self: *Parser) ?Token {
        const token: ?Token = self.peek();
        if (token != null) self.idx += 1;

        return token;
    }

    /// Returns the current token without advancing the parsing index.
    pub fn peek(self: *Parser) ?Token {
        if (self.idx >= self.tokens.len) return null;
        
        return self.tokens[self.idx];
    }

    /// Initializes a `Parser` instance for the given token stream.
    pub fn init(tokens: []Token, allocator: std.mem.Allocator) Parser {
        return Parser{ .tokens = tokens, .allocator = allocator, .idx = 0 };
    }

    /// Parses the token stream. Returns a slice of `Instruction` types.
    pub fn parse(self: *Parser) ![]Instruction {
        var instructions: std.ArrayList(Instruction) = try std.ArrayList(Instruction).initCapacity(self.allocator, 0);

        while (self.peek() != null) {
            const instruction: Instruction = try self.parseInstruction();
            try instructions.append(self.allocator, instruction);
        }
        return try instructions.toOwnedSlice(self.allocator);
    }
};
