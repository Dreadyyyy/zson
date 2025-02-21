const std = @import("std");

const ArrIter = struct {
    str: []const u8,

    pub fn next(self: *@This()) ?Json {
        const token, self.str = JsonParser.parseJson(self.str) catch return null;
        _, self.str = opt(comma)(self.str) catch unreachable;

        return token;
    }
};

const ObjIter = struct {
    str: []const u8,

    pub fn next(self: *@This()) ?struct { []const u8, Json } {
        const key, self.str = parseLiteral(self.str) catch return null;
        _, self.str = chain(.{ ws, stringLiteralParser(":"), ws })(self.str) catch unreachable;
        const val, self.str = JsonParser.parseJson(self.str) catch unreachable;
        _, self.str = opt(comma)(self.str) catch unreachable;

        return .{ key, val };
    }
};

pub const Json = union(enum) {
    JsonNull,
    JsonBool: bool,
    JsonNumber: i64,
    JsonFloat: f64,
    JsonString: []const u8,
    JsonArray: ArrIter,
    JsonObject: ObjIter,
};

pub const ParseError = error{
    UnexpectedToken,
    Overflow,
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
            return opt(parser)(str);
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

fn stringLiteralParser(comptime literal: []const u8) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            return if (std.mem.startsWith(u8, str, literal))
                .{ str[0..literal.len], str[literal.len..] }
            else
                ParseError.UnexpectedToken;
        }
    }.func;
}

fn toStringParser(comptime T: type, parser: Parser(T)) Parser([]const u8) {
    return struct {
        fn func(str: []const u8) ParseError!Parsed([]const u8) {
            _, const rest = try parser(str);
            return .{ str[0 .. str.len - rest.len], str[str.len - rest.len ..] };
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

const ws = opt(all(stringLiteralParser(" ")));
const comma = chain(.{ ws, stringLiteralParser(","), ws });
const sign = opt(choice(.{ stringLiteralParser("+"), stringLiteralParser("-") }));

pub const JsonParser = struct {
    fn parseNull(str: []const u8) ParseError!Parsed(Json) {
        _, const rest = try stringLiteralParser("null")(str);
        return .{ Json.JsonNull, rest };
    }

    fn parseBool(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try choice(.{ stringLiteralParser("true"), stringLiteralParser("false") })(str);
        return .{ Json{ .JsonBool = std.mem.eql(u8, token, "true") }, rest };
    }

    fn parseNumber(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try chain(.{ sign, all(parseDigit) })(str);
        return .{ Json{ .JsonNumber = std.fmt.parseInt(i64, token, 0) catch return ParseError.Overflow }, rest };
    }

    fn parseFloat(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try chain(.{ sign, all(parseDigit), stringLiteralParser("."), all(parseDigit) })(str);
        return .{ Json{ .JsonFloat = std.fmt.parseFloat(f64, token) catch return ParseError.Overflow }, rest };
    }

    fn parseString(str: []const u8) ParseError!Parsed(Json) {
        const token, const rest = try parseLiteral(str);
        return .{ Json{ .JsonString = token }, rest };
    }

    fn parseArray(str: []const u8) ParseError!Parsed(Json) {
        var rest = str;

        const token_start, rest = try chain(.{ ws, stringLiteralParser("["), ws })(rest);

        _, rest = try all(chain(.{ toStringParser(Json, parseJson), comma }))(rest);
        _, rest = opt(toStringParser(Json, parseJson))(rest) catch unreachable;

        _, rest = try chain(.{ ws, stringLiteralParser("]"), ws })(rest);

        return .{ Json{ .JsonArray = ArrIter{ .str = str[token_start.len..] } }, rest };
    }

    fn parseObject(str: []const u8) ParseError!Parsed(Json) {
        var rest = str;

        const token_start, rest = try chain(.{ ws, stringLiteralParser("{"), ws })(rest);

        const parsePair = chain(.{ toStringParser(Json, parseString), chain(.{ ws, stringLiteralParser(":"), ws }), toStringParser(Json, parseJson) });
        _, rest = try all(chain(.{ parsePair, comma }))(rest);
        _, rest = opt(parsePair)(rest) catch unreachable;

        _, rest = try chain(.{ ws, stringLiteralParser("}"), ws })(rest);

        return .{ Json{ .JsonObject = ObjIter{ .str = str[token_start.len..] } }, rest };
    }

    pub fn parseJson(str: []const u8) ParseError!Parsed(Json) {
        return parseObject(str) catch
            parseArray(str) catch
            parseString(str) catch
            parseFloat(str) catch
            parseNumber(str) catch
            parseBool(str) catch
            parseNull(str);
    }
};
