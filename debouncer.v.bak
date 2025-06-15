// File: debouncer.v
module debouncer #(
    parameter DEBOUNCE_CYCLES = 1000000 // Default for 20ms at 50MHz
) (
    input clk,
    input rst_n,             // Active low reset
    input key_in_raw,        // Raw input from physical key (active high)
    output reg key_out_debounced // Debounced key state (active high)
);

// For DEBOUNCE_CYCLES = 1,000,000, counter width is 20 bits.
reg [19:0] count_reg;     // Counter for debounce timing
reg key_temp_state;       // Temporary state to track changes

initial begin
    key_out_debounced = 1'b0; // Key inactive state (since active high)
    key_temp_state    = 1'b0; // Assume key is not pressed initially
    count_reg         = 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        key_out_debounced <= 1'b0;
        key_temp_state    <= 1'b0;
        count_reg         <= 0;
    end else begin
        if (key_in_raw != key_temp_state) begin
            // Raw input differs from last seen temporary state, means a potential change
            key_temp_state <= key_in_raw; // Update temporary state
            count_reg      <= 0;          // Reset counter
        end else begin
            // Raw input is the same as the temporary state (stable or changed and waiting)
            if (count_reg < DEBOUNCE_CYCLES - 1) begin
                count_reg <= count_reg + 1'b1;
            end else begin
                // Counter reached max, the key_temp_state is now considered stable
                key_out_debounced <= key_temp_state;
            end
        end
    end
end

endmodule