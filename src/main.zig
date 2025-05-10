const std = @import("std");
const Print = std.debug.print;
const Directory = std.fs.cwd();
const Input = std.io.getStdIn().reader();

pub fn main() !void {
    var arg_count: u8 = 0;
    var main_file_name: []const u8 = undefined;
    var ref_file_name: []const u8 = undefined;
    if (std.os.argv.len != 3) {
        Print("{s}\n", .{"!!! REQUIRES TWO ARGUMENTS !!!"});
        Print("{s}\n", .{"Arg.1 >> Main Raw Data."});
        Print("{s}\n", .{"Arg.2 >> Parent's Raw Data."});
        std.process.exit(1);
    }
    for (std.os.argv) |arg| {
        if (arg_count == 1) {
            main_file_name = std.mem.span(arg);
        }
        if (arg_count == 2) {
            ref_file_name = std.mem.span(arg);
        }
        arg_count += 1;
    }

    const main_file = try Directory.openFile(main_file_name, .{});
    defer main_file.close();

    const ref_file = try Directory.openFile("themes_mom.txt", .{});
    defer ref_file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var ref_map = std.StringHashMap([]const u8).init(allocator);

    const output_file = try Directory.createFile("output", .{});
    defer output_file.close();

    var buf: [1024]u8 = undefined;

    Print("{s}\n", .{"-> Processing parent's file..."});

    while (try ref_file.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len > 0 and line[0] == '#') {
            continue;
        }

        var splitted_line = std.mem.split(u8, line, "\t");
        const snp = try allocator.dupe(u8, splitted_line.first());
        const chr = splitted_line.next() orelse return error.MissingField;
        const pos = splitted_line.next() orelse return error.MissingField;
        const alleles = try allocator.dupe(u8, splitted_line.next() orelse return error.MissingField);
        _ = chr;
        _ = pos;

        try ref_map.put(snp, alleles);
    }

    Print("{s}\n", .{"-> Finished processing parent's file! Time for the child now..."});

    buf = undefined;

    while (try main_file.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (line.len > 0 and line[0] == '#') {
            continue;
        }

        var splitted_line = std.mem.split(u8, line, "\t");
        const snp = splitted_line.first();
        const chr = splitted_line.next() orelse return error.MissingField;
        const pos = splitted_line.next() orelse return error.MissingField;
        const alleles = splitted_line.next() orelse return error.MissingField;

        if (alleles[0] == alleles[1]) {
            try output_file.writer().print("{s}:{s}\t{c}|{c}\n", .{ chr, pos, alleles[0], alleles[1] });
        } else {
            if (ref_map.get(snp)) |val| {
                if (val[0] == val[1]) {
                    if (alleles[0] == val[0]) {
                        try output_file.writer().print("{s}:{s}\t{c}|{c}\n", .{ chr, pos, val[0], alleles[1] });
                    } else {
                        try output_file.writer().print("{s}:{s}\t{c}|{c}\n", .{ chr, pos, val[0], alleles[0] });
                    }
                } else {
                    continue;
                }
            } else {
                continue;
            }
        }
    }
}
