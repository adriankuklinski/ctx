const std = @import("std");
const zqlite = @import("zqlite");

const Item = struct {
    priority: u8,
    description: []const u8,
    created_at: i64,
};

pub fn main() !void {
    const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;
    var conn = try zqlite.open("/tmp/test.sqlite", flags);
    defer conn.close();

    const create_sql =
        \\CREATE TABLE IF NOT EXISTS items (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    priority INTEGER NOT NULL,
        \\    description TEXT NOT NULL,
        \\    created_at INTEGER NOT NULL
        \\)
    ;

    try conn.exec(create_sql, .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();

    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--ctx=")) {
            const item = Item{
                .priority = 0,
                .description = arg[6..],
                .created_at = std.time.timestamp(),
            };

            const insert_sql =
                \\INSERT INTO items (priority, description, created_at) 
                \\VALUES (?, ?, ?)
            ;

            try conn.exec(insert_sql, .{ item.priority, item.description, item.created_at });
        } else if (std.mem.eql(u8, arg, "--list")) {
            const query_sql =
                \\SELECT id, priority, description, created_at FROM items 
                \\ORDER BY created_at DESC
            ;

            var rows = try conn.rows(query_sql, .{});
            defer rows.deinit();

            while (rows.next()) |row| {
                const id = row.int(0);
                const priority = row.int(1);
                const description = row.text(2);
                const created_at = row.int(3);
                std.debug.print("#{}: [P{}] {s} (created: {})\n", .{ id, priority, description, created_at });
            }

            if (rows.err) |err| {
                return err;
            }
        } else if (std.mem.startsWith(u8, arg, "--delete=")) {
            const id = arg[9..];
            const delete_sql =
                \\DELETE FROM items WHERE items.id = ?
            ;

            try conn.exec(delete_sql, .{id});
        }
    }
}
