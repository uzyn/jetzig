<div>
  <h1>Parameters Debug Demo</h1>
  <p>Fill out the form below to see parameter debugging in action:</p>
  
  <form method="POST" action="/params">
    <div class="form-group">
      <label for="name">Name (required):</label>
      <input type="text" id="name" name="name" required>
    </div>
    
    <div class="form-group">
      <label for="favorite_animal">Favorite Animal (cat, dog, or raccoon):</label>
      <select id="favorite_animal" name="favorite_animal">
        <option value="cat">Cat</option>
        <option value="dog">Dog</option>
        <option value="raccoon">Raccoon</option>
      </select>
    </div>
    
    <div class="form-group">
      <label for="age">Age (optional, defaults to 100):</label>
      <input type="number" id="age" name="age">
    </div>
    
    <div class="form-group">
      <label for="extra_param">Extra Parameter (to demonstrate debugging):</label>
      <input type="text" id="extra_param" name="extra_param" value="This is an extra parameter">
    </div>
    
    <div class="form-group">
      <label for="nested[param]">Nested Parameter:</label>
      <input type="text" id="nested[param]" name="nested[param]" value="Nested value">
    </div>
    
    <button type="submit">Submit</button>
  </form>
  
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