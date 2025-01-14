const std = @import("std");
const testing = std.testing;

const JsonLexer = @import("root.zig").JsonLexer;
const Json = @import("root.zig").Json;

test "test parseNull" {
    const a = "nullabc";
    const b = "not null";

    try testing.expectEqualDeep(.{ .JsonNull, "abc" }, JsonLexer.parseJson(a).?);
    try testing.expectEqualDeep(null, JsonLexer.parseJson(b));
}

test "test parseBool" {
    const a = "truee";
    const b = "false";
    const c = "not bool";

    try testing.expectEqualDeep(.{ Json{ .JsonBool = true }, "e" }, JsonLexer.parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonBool = false }, "" }, JsonLexer.parseJson(b).?);
    try testing.expectEqualDeep(null, JsonLexer.parseJson(c));
}

test "test parseNumber" {
    const a = "-52345235";
    const b = "+25234523";
    const c = "25234523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonNumber = -52345235 }, "" }, JsonLexer.parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "" }, JsonLexer.parseJson(b).?);
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "a" }, JsonLexer.parseJson(c).?);
    try testing.expectEqualDeep(null, JsonLexer.parseJson(d));
}

test "test parseFloat" {
    const a = "-5234.5235";
    const b = "+25234.523";
    const c = "25234.523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonFloat = -5234.5235 }, "" }, JsonLexer.parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "" }, JsonLexer.parseJson(b).?);
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "a" }, JsonLexer.parseJson(c).?);
    try testing.expectEqualDeep(null, JsonLexer.parseJson(d));
}

test "test parseString" {
    const a = "\"foobar\"rest";
    const b = "not a literal";

    try testing.expectEqualDeep(.{ Json{ .JsonString = "foobar" }, "rest" }, JsonLexer.parseJson(a).?);
    try testing.expectEqualDeep(null, JsonLexer.parseJson(b));
}
