// File: keyboard_scanner.v
module keyboard_scanner #(
    parameter NUM_KEYS = 7,
    parameter DEBOUNCE_TIME_MS = 20
) (
    input clk,
    input rst_n,                          // Active low reset
    input [NUM_KEYS-1:0] keys_in_raw,   // Raw inputs from keys (Key1 to Key7, active high)
                                        // keys_in_raw[0] for Key1, ..., keys_in_raw[6] for Key7

    output reg [2:0] active_key_id,     // ID of the pressed key (0 for none, 1-7 for Key1-Key7)
    output reg key_is_pressed           // High if any key is currently pressed (debounced)
);

// Calculate debounce cycles based on 50MHz clock
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000);

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

// Declare loop variable for Verilog-2001 compatibility
integer j;

// Logic to determine active_key_id and key_is_pressed
// Priority: If multiple keys are pressed, lowest index key (highest priority) wins.
always @(*) begin
    key_is_pressed = 1'b0;      // Initialize: assume no key is pressed yet
    active_key_id = 3'd0;       // Initialize: default to no key ID

    // Iterate from lowest index (Key1, which is keys_debounced_signals[0])
    // to highest. The first one found will set the outputs.
    for (j = 0; j < NUM_KEYS; j = j + 1) begin
        if (keys_debounced_signals[j]) begin // If this key 'j' is pressed
            if (!key_is_pressed) begin       // AND if we haven't already found a lower-index pressed key
                key_is_pressed = 1'b1;
                active_key_id = j + 1;     // Assign its ID (j=0 is ID 1, j=1 is ID 2, etc.)
                                           // Note: j+1 values (1 to 7) fit in active_key_id [2:0]
            end
        end
    end
end

endmodule