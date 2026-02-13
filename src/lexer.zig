const std = @import("std");

pub const TokenType = enum(u2) { SPACE, TAB, LINEFEED };

pub const Token = struct {
    type: TokenType,
    lineno: usize,
    idx: usize,

    /// Prints a formatted `Token` to stdout.
    pub fn print(self: *const Token) void {
        std.debug.print("Token{{ .type = {}, .lineno = {d}, .idx = {d} }}\n", .{ self.type, self.lineno, self.idx });
    }
};

pub const Lexer = struct {
    text: []u8,
    allocator: std.mem.Allocator,
    lineno: usize,
    idx: usize,

    /// Initializes a `Lexer` instance for the given source text.
    pub fn init(text: []u8, allocator: std.mem.Allocator) Lexer {
        return Lexer{ .text = text, .allocator = allocator, .lineno = 1, .idx = 0 };
    }

    /// Performs lexical analysis on the source text. Returns a slice of `Token` types.
    pub fn lex(self: *Lexer) ![]Token {
        var token_type: TokenType = undefined;
        var tokens = try std.ArrayList(Token).initCapacity(self.allocator, 0);

        for (self.text) |char| {
            if (char != ' ' and char != '\t' and char != '\n') continue;
            
            switch (char) {
                ' ' => token_type = .SPACE,
                '\t' => token_type = .TAB,
                else => {
                    token_type = .LINEFEED;
                    self.lineno += 1;
                }
            }
            try tokens.append(self.allocator, Token{ .type = token_type, .lineno = self.lineno, .idx = self.idx });
            self.idx += 1;
        }
        return try tokens.toOwnedSlice(self.allocator);
    }
};
