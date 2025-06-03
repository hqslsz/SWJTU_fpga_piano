// File: keyboard_scanner.v
// Scans multiple keys, debounces them, and outputs the ID of the highest priority pressed key.

module keyboard_scanner #(
    parameter NUM_KEYS = 7, // Default value, will be overridden by the top module (e.g., to 12)
    parameter DEBOUNCE_TIME_MS = 20
) (
    input clk,
    input rst_n,                          // Active low reset
    input [NUM_KEYS-1:0] keys_in_raw,   // Raw inputs from keys (e.g., keys_in_raw[0] for Key1)

    // Output ID can be 0 (no key) or 1 up to NUM_KEYS.
    // So, it needs to represent NUM_KEYS + 1 distinct values.
    // The width required is $clog2(NUM_KEYS + 1).
    // Example: NUM_KEYS = 7 -> $clog2(8) = 3 bits (for 0-7)
    // Example: NUM_KEYS = 12 -> $clog2(13) = 4 bits (for 0-12)
    output reg [$clog2(NUM_KEYS + 1) - 1 : 0] active_key_id,
    output reg key_is_pressed           // High if any key is currently pressed (debounced)
);

// Calculate debounce cycles based on 50MHz clock (passed via DEBOUNCE_TIME_MS)
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000); // Assuming 50MHz clock

// Array of debounced key states
wire [NUM_KEYS-1:0] keys_debounced_signals;

// Instantiate debouncers for each key
genvar i;
generate
    for (i = 0; i < NUM_KEYS; i = i + 1) begin : debounce_gen_block
        debouncer #(
            .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC)
        ) inst_debouncer (
            .clk(clk),
            .rst_n(rst_n),
            .key_in_raw(keys_in_raw[i]),
            .key_out_debounced(keys_debounced_signals[i])
        );
    end
endgenerate

// Declare loop variable for Verilog-2001 compatibility if needed by older tools
// For modern tools, 'j' can be declared directly in the for loop if 'automatic' is not desired for synthesis.
integer j;

// Logic to determine active_key_id and key_is_pressed
// Priority: If multiple keys are pressed, lowest index key (keys_in_raw[0]) wins.
always @(*) begin
    key_is_pressed = 1'b0;      // Initialize: assume no key is pressed yet
    // Initialize active_key_id to 0 (no key pressed). Ensure correct width.
    active_key_id = {$clog2(NUM_KEYS + 1){1'b0}};

    // Iterate from lowest index (Key1, which is keys_debounced_signals[0])
    // to highest. The first one found will set the outputs.
    for (j = 0; j < NUM_KEYS; j = j + 1) begin
        if (keys_debounced_signals[j]) begin // If this key 'j' is pressed
            if (!key_is_pressed) begin       // AND if we haven't already found a lower-index pressed key
                key_is_pressed = 1'b1;
                active_key_id = j + 1;     // Assign its ID (j=0 is ID 1, j=1 is ID 2, etc.)
            end
        end
    end
end

endmodule