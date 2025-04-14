<div>
  <h1>Params Demo</h1>
  <p>This page demonstrates parameter handling in Jetzig.</p>
  <p>Check the server logs to see the parameter debug output.</p>
  
  <h2>Your Submitted Data:</h2>
  <pre>{info}</pre>
  
  <h2>How to Use Parameter Debugging</h2>
  <pre class="code-example">
// In your route handler:
const params = try request.params();
const formatted_params = try request.formatParameters(params);
std.debug.print("{s}\n", .{formatted_params});

// Or simply:
const params = try request.params();
std.debug.print("{any}\n", .{params});
  </pre>
</div>
