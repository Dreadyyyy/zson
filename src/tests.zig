const std = @import("std");
const testing = std.testing;

const parseJson = @import("root.zig").parseJson;
const Json = @import("root.zig").Json;

test "test parseNull" {
    const a = "nullabc";
    const b = "not null";

    try testing.expectEqualDeep(.{ .JsonNull, "abc" }, parseJson(a).?);
    try testing.expectEqualDeep(null, parseJson(b));
}

test "test parseBool" {
    const a = "truee";
    const b = "false";
    const c = "not bool";

    try testing.expectEqualDeep(.{ Json{ .JsonBool = true }, "e" }, parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonBool = false }, "" }, parseJson(b).?);
    try testing.expectEqualDeep(null, parseJson(c));
}

test "test parseNumber" {
    const a = "-52345235";
    const b = "+25234523";
    const c = "25234523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonNumber = -52345235 }, "" }, parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "" }, parseJson(b).?);
    try testing.expectEqualDeep(.{ Json{ .JsonNumber = 25234523 }, "a" }, parseJson(c).?);
    try testing.expectEqualDeep(null, parseJson(d));
}

test "test parseFloat" {
    const a = "-5234.5235";
    const b = "+25234.523";
    const c = "25234.523a";
    const d = "not a number";

    try testing.expectEqualDeep(.{ Json{ .JsonFloat = -5234.5235 }, "" }, parseJson(a).?);
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "" }, parseJson(b).?);
    try testing.expectEqualDeep(.{ Json{ .JsonFloat = 25234.523 }, "a" }, parseJson(c).?);
    try testing.expectEqualDeep(null, parseJson(d));
}
