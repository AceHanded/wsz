const std = @import("std");
const wsz = @import("wsz");
const log = wsz.log;
const lexer = wsz.lexer;
const parser = wsz.parser;
const VM = wsz.vm.VM;

pub fn main() !void {
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        try log.print("Usage: wsz <file>", .INFO);
        return;
    }
    const file: std.fs.File = std.fs.cwd().openFile(args[1], .{ .mode = .read_only }) catch |err| {
        try log.print(@errorName(err), .ERROR);
        return;
    };
    defer file.close();

    const stat: std.fs.File.Stat = try file.stat();
    const contents: []u8 = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(contents);

    var lex: lexer.Lexer = lexer.Lexer.init(contents, allocator);
    const tokens: []lexer.Token = try lex.lex();

    var parse: parser.Parser = parser.Parser.init(tokens, allocator);
    const instructions: []parser.Instruction = parse.parse() catch |err| {
        try log.print(@errorName(err), .ERROR);
        return;
    };
    var virtual_machine: VM = try VM.init(instructions, allocator);
    virtual_machine.run() catch |err| {
        try log.print(@errorName(err), .ERROR);
        return;
    };
}
