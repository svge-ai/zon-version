const std = @import("std");
const posix = std.posix;

fn writeStdout(msg: []const u8) void {
    _ = posix.write(posix.STDOUT_FILENO, msg) catch {};
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        printUsage();
        std.process.exit(1);
    }

    const command = args[1];
    const file_path = args[2];

    const content = std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024) catch |err| {
        std.debug.print("error: could not read {s}: {}\n", .{ file_path, err });
        std.process.exit(1);
    };
    defer allocator.free(content);

    const version = extractVersion(content) orelse {
        std.debug.print("error: no version field found in {s}\n", .{file_path});
        std.process.exit(1);
    };

    if (std.mem.eql(u8, command, "get")) {
        writeStdout(version.value);
        writeStdout("\n");
        return;
    }

    if (std.mem.eql(u8, command, "set")) {
        if (args.len < 4) {
            std.debug.print("error: set requires a version argument\n", .{});
            std.process.exit(1);
        }
        const new_version = args[3];
        try writeVersion(allocator, file_path, content, version, new_version);
        writeStdout(new_version);
        writeStdout("\n");
        return;
    }

    if (std.mem.eql(u8, command, "bump")) {
        const bump_type = if (args.len >= 4) args[3] else "patch";
        const new_version = try bumpVersion(allocator, version.value, bump_type);
        defer allocator.free(new_version);
        try writeVersion(allocator, file_path, content, version, new_version);
        writeStdout(new_version);
        writeStdout("\n");
        return;
    }

    printUsage();
    std.process.exit(1);
}

const VersionSpan = struct {
    value: []const u8,
    start: usize,
    end: usize,
};

fn extractVersion(content: []const u8) ?VersionSpan {
    const needle = ".version";
    var i: usize = 0;
    while (i + needle.len < content.len) : (i += 1) {
        if (std.mem.startsWith(u8, content[i..], needle)) {
            var j = i + needle.len;
            while (j < content.len and (content[j] == ' ' or content[j] == '=' or content[j] == '\t')) : (j += 1) {}
            while (j < content.len and (content[j] == ' ' or content[j] == '\t')) : (j += 1) {}
            if (j < content.len and content[j] == '"') {
                const start = j;
                j += 1;
                const val_start = j;
                while (j < content.len and content[j] != '"') : (j += 1) {}
                if (j < content.len) {
                    return VersionSpan{
                        .value = content[val_start..j],
                        .start = start,
                        .end = j + 1,
                    };
                }
            }
        }
    }
    return null;
}

fn writeVersion(allocator: std.mem.Allocator, file_path: []const u8, content: []const u8, version: VersionSpan, new_version: []const u8) !void {
    const new_content = try std.fmt.allocPrint(allocator, "{s}\"{s}\"{s}", .{
        content[0..version.start],
        new_version,
        content[version.end..],
    });
    defer allocator.free(new_content);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(new_content);
}

fn bumpVersion(allocator: std.mem.Allocator, version: []const u8, bump_type: []const u8) ![]u8 {
    var parts: [3]u32 = .{ 0, 0, 0 };
    var part_idx: usize = 0;
    for (version) |ch| {
        if (ch == '.') {
            part_idx += 1;
            if (part_idx >= 3) break;
        } else if (ch >= '0' and ch <= '9') {
            parts[part_idx] = parts[part_idx] * 10 + (ch - '0');
        }
    }

    if (std.mem.eql(u8, bump_type, "major")) {
        parts[0] += 1;
        parts[1] = 0;
        parts[2] = 0;
    } else if (std.mem.eql(u8, bump_type, "minor")) {
        parts[1] += 1;
        parts[2] = 0;
    } else {
        parts[2] += 1;
    }

    return try std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ parts[0], parts[1], parts[2] });
}

fn printUsage() void {
    std.debug.print(
        \\zon-version — Read and bump versions in build.zig.zon files
        \\
        \\Usage:
        \\  zon-version get <file>                  Print current version
        \\  zon-version set <file> <version>         Set version to specific value
        \\  zon-version bump <file> [patch|minor|major]  Bump version (default: patch)
        \\
    , .{});
}
