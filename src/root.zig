const std = @import("std");

pub const Json = union(enum) {
    JsonNull,
    JsonBool: bool,
    JsonNumber: i64,
    JsonFloat: f64,
    JsonString: []const u8,
    JsonArray: std.ArrayList(Json),
    JsonObject: std.StringHashMap(Json),

    pub fn toStr(self: *const @This(), allocator: std.mem.Allocator) !std.ArrayList(u8) {
        var res = std.ArrayList(u8).init(allocator);
        errdefer res.deinit();

        switch (self.*) {
            .JsonNull => try res.appendSlice("null"),
            inline .JsonBool, .JsonNumber, .JsonFloat => |val| {
                const slice = try std.fmt.allocPrint(allocator, "{}", .{val});
                defer allocator.free(slice);
                try res.appendSlice(slice);
            },
            .JsonString => |str| try res.appendSlice(str),
            .JsonArray => |arr| {
                try res.append('[');

                for (arr.items, 0..) |el, idx| {
                    try res.append(' ');

                    const str = try el.toStr(allocator);
                    defer str.deinit();
                    try res.appendSlice(str.items);

                    try res.append(if (idx != arr.items.len - 1) ',' else ' ');
                }

                try res.append(']');
            },
            .JsonObject => |obj| {
                try res.append('{');

                var iter = obj.iterator();
                var idx: usize = 0;
                const size = obj.count();

                while (iter.next()) |pair| {
                    const left = try std.fmt.allocPrint(allocator, " \"{s}\":", .{pair.key_ptr.*});
                    defer allocator.free(left);
                    try res.appendSlice(left);

                    const right = try pair.value_ptr.toStr(allocator);
                    defer right.deinit();
                    try res.appendSlice(right.items);

                    try res.append(if (idx != size - 1) ',' else ' ');
                    idx += 1;
                }

                try res.append('}');
            },
        }

        return res;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .JsonArray => |arr| {
                defer arr.deinit();
                for (0..arr.items.len) |idx| arr.items[idx].deinit(allocator);
            },
            .JsonObject => |obj| {
                defer self.JsonObject.deinit();
                var iter = obj.iterator();
                while (iter.next()) |pair| pair.value_ptr.deinit(allocator);
            },
            else => {},
        }
    }
};

pub const ParseError = error{
    UnexpectedToken,
    Overflow,
    MemoryError,
};

fn Parsed(comptime T: type) type {
    return struct { T, []const u8 };
}

fn Parser(comptime T: type) type {
    return fn ([]const u8) ParseError!Parsed(T);
}

fn opt(comptime parser: Parser([]const u8)) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            return parser(str) catch .{ "", str };
        }
    }.func;
}

fn all(comptime parser: Parser([]const u8)) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            _, var rest = try parser(str);
            while (true) _, rest = parser(rest) catch break;

            return .{ str[0..(str.len - rest.len)], rest };
        }
    }.func;
}

fn chain(comptime parsers: anytype) Parser([]const u8) {
    const fields = std.meta.fields(@TypeOf(parsers));

    comptime var parsers_list: [fields.len]Parser([]const u8) = undefined;

    inline for (fields, 0..) |field, idx|
        parsers_list[idx] = @field(parsers, field.name);

    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            var rest = str;

            inline for (parsers_list) |parser|
                _, rest = try parser(rest);

            return .{ str[0..(str.len - rest.len)], rest };
        }
    }.func;
}

fn choice(comptime parsers: anytype) Parser([]const u8) {
    const fields = std.meta.fields(@TypeOf(parsers));
    const len = fields.len;

    comptime var parsers_list: [len]Parser([]const u8) = undefined;

    inline for (fields, 0..) |field, idx|
        parsers_list[idx] = @field(parsers, field.name);

    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            inline for (parsers_list) |parser|
                if (parser(str) catch null) |parsed| return parsed;

            return ParseError.UnexpectedToken;
        }
    }.func;
}

fn stringParser(comptime literal: []const u8) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            return if (std.mem.startsWith(u8, str, literal))
                .{ str[0..literal.len], str[literal.len..] }
            else
                ParseError.UnexpectedToken;
        }
    }.func;
}

fn parseDigit(str: []const u8) ParseError!Parsed([]const u8) {
    if (str.len == 0) return ParseError.UnexpectedToken;

    return if (std.ascii.isDigit(str[0]))
        .{ str[0..1], str[1..] }
    else
        ParseError.UnexpectedToken;
}

fn parseLiteral(str: []const u8) ParseError!Parsed([]const u8) {
    if (str.len == 0 or str[0] != '"') return ParseError.UnexpectedToken;

    for (str[0 .. str.len - 1], str[1..], 1..) |chr1, chr2, idx|
        if (chr2 == '"' and chr1 != '\\') return .{ str[1..idx], str[idx + 1 ..] };

    return ParseError.UnexpectedToken;
}

const delims = opt(all(choice(.{ stringParser(" "), stringParser("\n") })));
const comma = chain(.{ delims, stringParser(","), delims });
const sign = opt(choice(.{ stringParser("+"), stringParser("-") }));

pub const JsonParser = struct {
    allocator: std.mem.Allocator,

    fn parseNull(str: []const u8) ParseError!Parsed(Json) {
        _, const rest = try stringParser("null")(str);
        return .{ Json.JsonNull, rest };
    }

    fn parseBool(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try choice(.{ stringParser("true"), stringParser("false") })(str);
        return .{ Json{ .JsonBool = std.mem.eql(u8, token, "true") }, rest };
    }

    fn parseNumber(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try chain(.{ sign, all(parseDigit) })(str);
        return .{ Json{ .JsonNumber = std.fmt.parseInt(i64, token, 0) catch return ParseError.Overflow }, rest };
    }

    fn parseFloat(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try chain(.{ sign, all(parseDigit), stringParser("."), all(parseDigit) })(str);
        return .{ Json{ .JsonFloat = std.fmt.parseFloat(f64, token) catch return ParseError.Overflow }, rest };
    }

    fn parseString(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try parseLiteral(str);
        return .{ Json{ .JsonString = token }, rest };
    }

    fn parseArray(self: *const @This(), str: []const u8) ParseError!Parsed(Json) {
        var arr = std.ArrayList(Json).init(self.allocator);
        errdefer arr.deinit();

        var rest = str;

        _, rest = try chain(.{ delims, stringParser("["), delims })(rest);

        while (true) {
            const token, rest = self.parseJson(rest) catch break;
            arr.append(token) catch return ParseError.MemoryError;

            _, rest = comma(rest) catch break;
        }

        _, rest = try chain(.{ delims, stringParser("]"), delims })(rest);

        return .{ Json{ .JsonArray = arr }, rest };
    }

    fn parseObject(self: *const @This(), str: []const u8) ParseError!Parsed(Json) {
        var obj = std.StringHashMap(Json).init(self.allocator);
        errdefer obj.deinit();

        var rest = str;

        _, rest = try chain(.{ delims, stringParser("{"), delims })(rest);

        while (true) {
            const key, rest = parseLiteral(rest) catch break;
            _, rest = try chain(.{ delims, stringParser(":"), delims })(rest);
            const val, rest = try self.parseJson(rest);

            obj.put(key, val) catch return ParseError.MemoryError;

            _, rest = comma(rest) catch break;
        }

        _, rest = try chain(.{ delims, stringParser("}"), delims })(rest);

        return .{ Json{ .JsonObject = obj }, rest };
    }

    pub fn parseJson(self: *const @This(), str: []const u8) ParseError!Parsed(Json) {
        return parseObject(self, str) catch
            parseArray(self, str) catch
            parseString(str) catch
            parseFloat(str) catch
            parseNumber(str) catch
            parseBool(str) catch
            parseNull(str);
    }
};
