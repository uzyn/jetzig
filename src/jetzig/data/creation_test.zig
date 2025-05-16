const std = @import("std");
const testing = std.testing;
// Import through a relative path to match how other test files are importing jetzig
const jetzig = @import("../../jetzig.zig");

test "direct creation with arrays and objects" {
    // Set up an arena allocator for the test
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    // We'll defer the deallocation until after all tests are complete
    // to avoid premature memory release
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Define some data we'd normally convert from a model
    const user_id = 42;
    // String values should be duplicated by the data.string() function
    // to ensure they live for the duration of the test
    const user_name = "John Doe";
    const user_email = "john@example.com";
    const favorites = [_]struct{u64, []const u8}{
        .{1, "First Favorite"},
        .{2, "Second Favorite"},
    };
    const tags = [_][]const u8{"tag1", "tag2", "tag3"};
    
    // Create a data object and ensure it stays alive for the duration of the test
    var data_obj = jetzig.data.Data.init(allocator);
    // data_obj will be in scope until the end of the test
    var root = try data_obj.root(.object);
    
    // Build the complex structure manually using root
    try root.put("id", data_obj.integer(user_id));
    try root.put("name", data_obj.string(user_name));
    try root.put("email", data_obj.string(user_email));
    
    // Create favorites array
    var favorites_array = try jetzig.data.Data.createArray(allocator);
    for (favorites) |fav| {
        var fav_obj = try jetzig.data.Data.createObject(allocator);
        try fav_obj.put("id", data_obj.integer(fav[0]));
        try fav_obj.put("name", data_obj.string(fav[1]));
        try favorites_array.append(fav_obj);
    }
    try root.put("favorites", favorites_array);
    
    // Create tags array
    var tags_array = try jetzig.data.Data.createArray(allocator);
    for (tags) |tag| {
        try tags_array.append(data_obj.string(tag));
    }
    try root.put("tags", tags_array);
    
    // Verify the structure
    const id_val = root.object.get("id").?;
    try testing.expect(@as(jetzig.data.ValueType, id_val.*) == .integer);
    try testing.expectEqual(@as(i64, 42), id_val.integer.value);
    
    const name_val = root.object.get("name").?;
    try testing.expect(@as(jetzig.data.ValueType, name_val.*) == .string);
    try testing.expectEqualStrings("John Doe", name_val.string.value);
    
    const email_val = root.object.get("email").?;
    try testing.expect(@as(jetzig.data.ValueType, email_val.*) == .string);
    try testing.expectEqualStrings("john@example.com", email_val.string.value);
    
    // Verify favorites
    const favorites_val = root.object.get("favorites").?;
    try testing.expect(@as(jetzig.data.ValueType, favorites_val.*) == .array);
    try testing.expectEqual(@as(usize, 2), favorites_val.array.array.items.len);
    
    const fav1 = favorites_val.array.array.items[0];
    try testing.expect(@as(jetzig.data.ValueType, fav1.*) == .object);
    try testing.expectEqual(@as(i64, 1), fav1.object.get("id").?.integer.value);
    try testing.expectEqualStrings("First Favorite", fav1.object.get("name").?.string.value);
    
    // Verify tags
    const tags_val = root.object.get("tags").?;
    try testing.expect(@as(jetzig.data.ValueType, tags_val.*) == .array);
    try testing.expectEqual(@as(usize, 3), tags_val.array.array.items.len);
    try testing.expectEqualStrings("tag1", tags_val.array.array.items[0].string.value);
    try testing.expectEqualStrings("tag2", tags_val.array.array.items[1].string.value);
    try testing.expectEqualStrings("tag3", tags_val.array.array.items[2].string.value);
}