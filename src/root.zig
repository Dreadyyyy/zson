const std = @import("std");
const eql = std.mem.eql;

pub const Json = union(enum) {
    JsonNull,
    JsonBool: bool,
    JsonNumber: i64,
    JsonFloat: f64,
    JsonString: []const u8,
    JsonArray: std.ArrayList(Json),
    JsonObject: std.StringHashMap(Json),
};

fn Parsed(comptime T: type) type {
    return struct { T, []const u8 };
}

fn Parser(comptime T: type) type {
    return fn ([]const u8) ?Parsed(T);
}

fn opt(comptime parser: Parser([]const u8)) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ?Parsed([]const u8) {
            return parser(str) orelse .{ "", str };
        }
    }.func;
}

fn all(comptime parser: Parser([]const u8)) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ?Parsed([]const u8) {
            var rest = str;
            while (parser(rest)) |parsed| _, rest = parsed;

            return if (str.len != rest.len)
                .{ str[0..(str.len - rest.len)], rest }
            else
                null;
        }
    }.func;
}

fn chain(comptime parsers: anytype) Parser([]const u8) {
    const fields = std.meta.fields(@TypeOf(parsers));

    comptime var parsers_list: [fields.len]Parser([]const u8) = undefined;

    inline for (fields, 0..) |field, idx|
        parsers_list[idx] = @field(parsers, field.name);

    return struct {
        fn func(str: []const u8) ?Parsed([]const u8) {
            var rest = str;

            inline for (parsers_list) |parser|
                _, rest = parser(rest) orelse return null;

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
        fn func(str: []const u8) ?Parsed([]const u8) {
            inline for (parsers_list) |parser| {
                const parsed = parser(str);
                if (parsed != null) return parsed;
            }

            return null;
        }
    }.func;
}

fn stringParser(comptime literal: []const u8) Parser([]const u8) {
    const len = literal.len;

    return struct {
        fn func(str: []const u8) ?Parsed([]const u8) {
            return if (str.len >= len and eql(u8, str[0..len], literal))
                .{ str[0..len], str[len..] }
            else
                null;
        }
    }.func;
}

fn parseDigit(str: []const u8) ?Parsed([]const u8) {
    if (str.len == 0) return null;

    return if (str[0] >= '0' and str[0] <= '9')
        .{ str[0..1], str[1..] }
    else
        null;
}

fn parseLiteral(str: []const u8) ?Parsed([]const u8) {
    var parsed: usize = 0;

    for (str) |chr| {
        if (chr == '"') break;
        parsed += 1;
    }

    return if (parsed != 0) .{ str[0..parsed], str[parsed..] } else null;
}

const delims = opt(all(choice(.{ stringParser(" "), stringParser("\n") })));
const comma = chain(.{ delims, stringParser(","), delims });
const sign = opt(choice(.{ stringParser("+"), stringParser("-") }));

pub const JsonLexer = struct {
    allocator: std.mem.Allocator,

    fn parseNull(str: []const u8) ?Parsed(Json) {
        _, const rest = stringParser("null")(str) orelse return null;

        return .{ Json.JsonNull, rest };
    }

    fn parseBool(str: []const u8) ?Parsed(Json) {
        const token, const rest = stringParser("true")(str) orelse
            stringParser("false")(str) orelse
            return null;

        return .{ Json{ .JsonBool = eql(u8, token, "true") }, rest };
    }

    fn parseNumber(str: []const u8) ?Parsed(Json) {
        const token, const rest = chain(.{ sign, all(parseDigit) })(str) orelse return null;

        return .{ Json{ .JsonNumber = std.fmt.parseInt(i64, token, 0) catch return null }, rest };
    }

    fn parseFloat(str: []const u8) ?Parsed(Json) {
        const token, const rest = chain(.{ sign, all(parseDigit), stringParser("."), all(parseDigit) })(str) orelse return null;

        return .{ Json{ .JsonFloat = std.fmt.parseFloat(f64, token) catch return null }, rest };
    }

    fn parseString(str: []const u8) ?Parsed(Json) {
        var rest = str;

        _, rest = stringParser("\"")(rest) orelse return null;
        const token, rest = parseLiteral(rest) orelse return null;
        _, rest = stringParser("\"")(rest) orelse return null;

        return .{ Json{ .JsonString = token }, rest };
    }

    fn parseArray(self: @This(), str: []const u8) ?Parsed(Json) {
        var value = std.ArrayList(Json).init(self.allocator);

        var rest = str;

        _, rest = chain(.{ delims, stringParser("["), delims })(rest) orelse {
            value.deinit();
            return null;
        };

        while (self.parseJson(rest)) |parsed| {
            const token, rest = parsed;
            value.append(token) catch unreachable;

            _, rest = comma(rest) orelse break;
        }

        _, rest = chain(.{ delims, stringParser("]"), delims })(rest) orelse {
            value.deinit();
            return null;
        };

        return .{ Json{ .JsonArray = value }, rest };
    }

    fn parseObject(self: @This(), str: []const u8) ?Parsed(Json) {
        var value = std.StringHashMap(Json).init(self.allocator);

        var rest = str;

        _, rest = chain(.{ delims, stringParser("{"), delims })(rest) orelse {
            value.deinit();
            return null;
        };

        while (parseString(rest)) |parsed| {
            const key, rest = parsed;

            _, rest = chain(.{ delims, stringParser(":"), delims })(rest) orelse {
                value.deinit();
                return null;
            };

            const val, rest = self.parseJson(rest) orelse {
                value.deinit();
                return null;
            };

            value.put(key.JsonString, val) catch unreachable;

            _, rest = comma(rest) orelse break;
        }

        _, rest = chain(.{ delims, stringParser("}"), delims })(rest) orelse {
            value.deinit();
            return null;
        };

        return .{ Json{ .JsonObject = value }, rest };
    }

    pub fn parseJson(self: @This(), str: []const u8) ?Parsed(Json) {
        return self.parseObject(str) orelse self.parseArray(str) orelse parseString(str) orelse parseFloat(str) orelse parseNumber(str) orelse parseBool(str) orelse parseNull(str);
    }
};
