const std = @import("std");
const jetzig = @import("jetzig.zig");

test {
    // NOTE: The following tests are related to zmplValue() have known issues with string corruption:
    // - jetzig/data/simple_nested_test.zig
    // - jetzig/data/complex_value_test.zig
    // Instead, we're focusing on the new fromModel() implementation which works correctly.
    
    std.debug.assert(jetzig.jetquery.jetcommon == jetzig.zmpl.jetcommon);
    std.debug.assert(jetzig.zmpl.jetcommon == jetzig.jetcommon);
    _ = @import("jetzig/http/Query.zig");
    _ = @import("jetzig/http/Headers.zig");
    _ = @import("jetzig/http/Cookies.zig");
    _ = @import("jetzig/http/Session.zig");
    _ = @import("jetzig/http/Path.zig");
    _ = @import("jetzig/jobs/Job.zig");
    _ = @import("jetzig/mail/Mail.zig");
    _ = @import("jetzig/loggers/LogQueue.zig");
    _ = @import("jetzig/data/simple_nested_test.zig");
    _ = @import("jetzig/data/complex_value_test.zig");
    _ = @import("jetzig/data/creation_test.zig");
    _ = @import("jetzig/data/minimal_test.zig");
    _ = @import("jetzig/data/simple_from_model_test.zig");
    _ = @import("jetzig/data/from_model_complete_test.zig");
}
