const std = @import("std");
const testing = std.testing;

const JsonParser = @import("root.zig").JsonParser;
const Json = @import("root.zig").Json;
const ParseError = @import("root.zig").ParseError;

test "test parseNull" {
    const a = "nullabc";
    const b = "not null";

    try testing.expectEqualDeep(.{ .JsonNull, "abc" }, try JsonParser.parseJson(a));
    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(b));
}

test "test parseBool" {
    const a = "truee";
    const b = "false";
    const c = "not bool";

    try testing.expectEqualDeep(.{ Json{ .JsonBool = true }, "e" }, try JsonParser.parseJson(a));
    try testing.expectEqualDeep(.{ Json{ .JsonBool = false }, "" }, try JsonParser.parseJson(b));
    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(c));
}

test "test parseNumber" {
    const a = "-52345235";
    const b = "+25234523";
    const c = "25234523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonNumber = -52345235 }, "" }, try JsonParser.parseJson(a));
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "" }, try JsonParser.parseJson(b));
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "a" }, try JsonParser.parseJson(c));
    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(d));
}

test "test parseFloat" {
    const a = "-5234.5235";
    const b = "+25234.523";
    const c = "25234.523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonFloat = -5234.5235 }, "" }, try JsonParser.parseJson(a));
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "" }, try JsonParser.parseJson(b));
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "a" }, try JsonParser.parseJson(c));
    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(d));
}

test "test parseString" {
    const a = "\"foobar\"rest";
    const b = "not a literal";

    try testing.expectEqualDeep(.{ Json{ .JsonString = "foobar" }, "rest" }, try JsonParser.parseJson(a));
    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(b));
}

test "test parseArray" {
    const a = "  [ null, 123, \"foobar\" ]abc";
    const b = "[]";
    const c = "not an array";

    var array_a, const rest_a = try JsonParser.parseJson(a);
    try testing.expectEqualDeep("abc", rest_a);
    try testing.expectEqualDeep("JsonArray", @tagName(array_a));
    try testing.expectEqualDeep(Json.JsonNull, array_a.JsonArray.next());
    try testing.expectEqualDeep(Json{ .JsonNumber = 123 }, array_a.JsonArray.next());
    try testing.expectEqualDeep(Json{ .JsonString = "foobar" }, array_a.JsonArray.next());
    try testing.expectEqualDeep(null, array_a.JsonArray.next());

    var array_b, const rest_b = try JsonParser.parseJson(b);
    try testing.expectEqualDeep("", rest_b);
    try testing.expectEqualDeep("JsonArray", @tagName(array_b));
    try testing.expectEqualDeep(null, array_b.JsonArray.next());

    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(c));
}

test "test parseObject" {
    const a = " { \"foo\": \"bar\"  , \"bar\"  :null}rest";
    const b = "not an object";

    var object_a, const rest_a = try JsonParser.parseJson(a);

    try testing.expectEqualDeep("rest", rest_a);
    try testing.expectEqualDeep("JsonObject", @tagName(object_a));
    try testing.expectEqualDeep(.{ "foo", Json{ .JsonString = "bar" } }, object_a.JsonObject.next());
    try testing.expectEqualDeep(.{ "bar", Json.JsonNull }, object_a.JsonObject.next());
    try testing.expectEqualDeep(null, object_a.JsonObject.next());

    try testing.expectError(ParseError.UnexpectedToken, JsonParser.parseJson(b));
}
