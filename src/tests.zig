const std = @import("std");
const testing = std.testing;

const JsonLexer = @import("root.zig").JsonLexer;
const Json = @import("root.zig").Json;

test "test parseNull" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "nullabc";
    const b = "not null";

    try testing.expectEqualDeep(.{ .JsonNull, "abc" }, lexer.parseJson(a).?);
    try testing.expectEqualDeep(null, lexer.parseJson(b));
}

test "test parseBool" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "truee";
    const b = "false";
    const c = "not bool";

    try testing.expectEqualDeep(.{ Json{ .JsonBool = true }, "e" }, lexer.parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonBool = false }, "" }, lexer.parseJson(b).?);
    try testing.expectEqualDeep(null, lexer.parseJson(c));
}

test "test parseNumber" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "-52345235";
    const b = "+25234523";
    const c = "25234523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonNumber = -52345235 }, "" }, lexer.parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "" }, lexer.parseJson(b).?);
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "a" }, lexer.parseJson(c).?);
    try testing.expectEqualDeep(null, lexer.parseJson(d));
}

test "test parseFloat" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "-5234.5235";
    const b = "+25234.523";
    const c = "25234.523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonFloat = -5234.5235 }, "" }, lexer.parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "" }, lexer.parseJson(b).?);
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "a" }, lexer.parseJson(c).?);
    try testing.expectEqualDeep(null, lexer.parseJson(d));
}

test "test parseString" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "\"foobar\"rest";
    const b = "not a literal";

    try testing.expectEqualDeep(.{ Json{ .JsonString = "foobar" }, "rest" }, lexer.parseJson(a).?);
    try testing.expectEqualDeep(null, lexer.parseJson(b));
}

test "test parseArray" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "  [ null, 123, \"foobar\" ]abc";
    const b = "[]";
    const c = "not an array";

    const array_a, const rest_a = lexer.parseJson(a).?;
    try testing.expectEqualDeep(rest_a, "abc");
    try testing.expectEqualDeep(@tagName(array_a), "JsonArray");
    try testing.expectEqualDeep(array_a.JsonArray.items.len, 3);
    try testing.expectEqualDeep(array_a.JsonArray.items[0], Json.JsonNull);
    try testing.expectEqualDeep(array_a.JsonArray.items[1], Json{ .JsonNumber = 123 });
    try testing.expectEqualDeep(array_a.JsonArray.items[2], Json{ .JsonString = "foobar" });

    const array_b, const rest_b = lexer.parseJson(b).?;
    try testing.expectEqualDeep(rest_b, "");
    try testing.expectEqualDeep(@tagName(array_b), "JsonArray");
    try testing.expectEqualDeep(array_b.JsonArray.items.len, 0);

    try testing.expectEqualDeep(null, lexer.parseJson(c));
}

test "test parseObject" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = " { \"foo\": \"bar\"  , \"bar\"  :null}rest";
    const b = "not an object";

    const object_a, const rest_a = lexer.parseJson(a).?;
    std.debug.print("{s}\n", .{(try object_a.toStr(arena.allocator())).items});
    try testing.expectEqualDeep("rest", rest_a);
    try testing.expectEqualDeep("JsonObject", @tagName(object_a));
    try testing.expectEqualDeep(Json{ .JsonString = "bar" }, object_a.JsonObject.get("foo").?);
    try testing.expectEqualDeep(Json.JsonNull, object_a.JsonObject.get("bar").?);

    try testing.expectEqualDeep(null, lexer.parseJson(b));
}

test "prints" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const lexer = JsonLexer{ .allocator = arena.allocator() };

    const a = "{ \"foo\":{ \"bar\" : [null, 123, 456.789 ]}, \"bar\"  : \"abc\", \"fizz\":[]}";

    const object_a, _ = lexer.parseJson(a).?;
    std.debug.print("{s}\n", .{(try object_a.toStr(arena.allocator())).items});
}
