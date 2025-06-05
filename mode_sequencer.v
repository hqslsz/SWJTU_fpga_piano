// File: mode_sequencer.v (Corrected and Refined)
module mode_sequencer (
    input clk,
    input rst_n,

    // Input from the main piano logic (debounced, highest priority key ID)
    input [3:0] current_live_key_id,         // 4-bit ID: 1-12 for notes, 0 for none
    input       current_live_key_pressed,    // Is a live key currently pressed?

    // Output to indicate practice mode activation
    output reg  practice_mode_active_pulse   // A single clock pulse when sequence is matched
);

// --- Parameters for the sequence ---
localparam SEQ_LENGTH = 7; // Length of your sequence "2317616"
// CORRECTED: Single line assignment for TARGET_SEQUENCE, ensure your Verilog version in Quartus is 2001 or SystemVerilog
function [3:0] get_target_sequence_val (input integer index);
    case (index)
        0: get_target_sequence_val = 4'd2;
        1: get_target_sequence_val = 4'd3;
        2: get_target_sequence_val = 4'd1;
        3: get_target_sequence_val = 4'd7;
        4: get_target_sequence_val = 4'd6;
        5: get_target_sequence_val = 4'd1;
        6: get_target_sequence_val = 4'd6;
        default: get_target_sequence_val = 4'dx; // Or some other default
    endcase
endfunction
// Then in your logic:
// if (current_live_key_id == get_target_sequence_val(current_match_index)) begin

// Timeout for sequence input (e.g., 2 seconds between key presses)
localparam TIMEOUT_MS = 2000; // 2 seconds
localparam CLK_FREQ_HZ = 50_000_000;
localparam TIMEOUT_CYCLES = (TIMEOUT_MS * (CLK_FREQ_HZ / 1000));

// --- Internal state and registers ---
// Corrected width for current_match_index to safely hold 0 to SEQ_LENGTH states (e.g., 0-6 for match, 7 for 'done' or use 0 to SEQ_LENGTH-1 as index)
// It needs to hold values from 0 up to SEQ_LENGTH-1 as an index.
// $clog2(SEQ_LENGTH) gives bits for 0 to SEQ_LENGTH-1. If SEQ_LENGTH=7, needs 3 bits (0-6).
reg [$clog2(SEQ_LENGTH > 1 ? SEQ_LENGTH : 2)-1:0] current_match_index; // e.g., for SEQ_LENGTH=7, [2:0]

reg [3:0] last_pressed_key_id_prev_cycle; // Stores key_id from previous cycle to detect new presses
reg [$clog2(TIMEOUT_CYCLES > 1 ? TIMEOUT_CYCLES : 2)-1:0] timeout_counter_reg;
reg sequence_input_active_flag; // Flag to indicate if we are in the middle of inputting a sequence

initial begin
    practice_mode_active_pulse = 1'b0;
    current_match_index = 0;
    last_pressed_key_id_prev_cycle = 4'd0; // No key initially
    timeout_counter_reg = 0;
    sequence_input_active_flag = 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        practice_mode_active_pulse <= 1'b0;
        current_match_index <= 0;
        last_pressed_key_id_prev_cycle <= 4'd0;
        timeout_counter_reg <= 0;
        sequence_input_active_flag <= 1'b0;
    end else begin
        // Default: pulse is low unless explicitly set high for one cycle
        practice_mode_active_pulse <= 1'b0;

        // Timeout logic
        if (sequence_input_active_flag) begin
            if (timeout_counter_reg >= TIMEOUT_CYCLES - 1) begin
                // Timeout occurred, reset sequence matching
                current_match_index <= 0;
                sequence_input_active_flag <= 1'b0;
                timeout_counter_reg <= 0;
            end else begin
                timeout_counter_reg <= timeout_counter_reg + 1'b1;
            end
        end else begin
            timeout_counter_reg <= 0; // Not in sequence, reset timer
        end

        // Key press detection and sequence matching logic
        // A new key press is when current_live_key_pressed is true,
        // and current_live_key_id is different from last_pressed_key_id_prev_cycle,
        // and current_live_key_id is not 0 (rest).
        if (current_live_key_pressed && current_live_key_id != 4'd0 && current_live_key_id != last_pressed_key_id_prev_cycle) begin
            // This is a new, valid musical key press event
            timeout_counter_reg <= 0;                 // Reset timeout timer on new key press
            sequence_input_active_flag <= 1'b1;       // We are now actively inputting/checking a sequence

            if (current_live_key_id == get_target_sequence_val(current_match_index)) begin
                // Correct key for the current step in the sequence
                if (current_match_index == SEQ_LENGTH - 1) begin
                    // Last key of the sequence matched!
                    practice_mode_active_pulse <= 1'b1; // Fire the pulse!
                    current_match_index <= 0;           // Reset for next time
                    sequence_input_active_flag <= 1'b0; // Sequence complete, no longer active
                end else begin
                    // Not the last key, but correct so far. Advance.
                    current_match_index <= current_match_index + 1'b1;
                end
            end else begin // Incorrect key pressed for the sequence
                // If the incorrect key is the start of a new target sequence, restart matching from step 1
                if (current_live_key_id == get_target_sequence_val(0)) begin
                    current_match_index <= 1; // Matched the first element of the sequence
                end else begin
                    current_match_index <= 0; // Wrong key, and it's not the start of a new sequence, reset.
                    sequence_input_active_flag <= 1'b0; 
                end
            end
        end

        // Update last_pressed_key_id_prev_cycle for the next clock cycle
        // If a key is pressed, store its ID. If no key is pressed, store 0.
        if (current_live_key_pressed && current_live_key_id != 4'd0) begin
            last_pressed_key_id_prev_cycle <= current_live_key_id;
        end else if (!current_live_key_pressed) begin // Key has been released
            last_pressed_key_id_prev_cycle <= 4'd0;
        end
        // If key is held (current_live_key_id == last_pressed_key_id_prev_cycle), 
        // last_pressed_key_id_prev_cycle remains, and the main `if` condition above won't trigger for "new press".
    end
end

endmodule