// File: seven_segment_controller.v (Modified for 3-digit display: Suffix, Note Digit, Octave)
module seven_segment_controller (
    input clk,                           // System clock (50MHz)
    input rst_n,                         // Active low reset

    // Inputs from fpga.v
    input [2:0] base_note_id_in,         // 0 for none, 1-7 for musical key's base number (for SEG1)
    input [1:0] semitone_type_in,        // 00: none, 01: sharp (#), 10: flat (b) (for SEG0)
    input display_active_flag,         // True if a valid musical note (not rest) is active for SEG0/SEG1 display
    input octave_up_active,            // True if octave up is active (for SEG2)
    input octave_down_active,          // True if octave down is active (for SEG2)

    // Outputs for 7-Segment Display
    output reg seg_a, output reg seg_b, output reg seg_c, output reg seg_d,
    output reg seg_e, output reg seg_f, output reg seg_g, output reg seg_dp,
    output reg [7:0] digit_selects       // For SEG0-SEG7, ACTIVE HIGH (we'll use [0],[1],[2])
);

// Segment patterns for COMMON CATHODE (1=ON, 0=OFF)
localparam PATTERN_0    = 7'b0111111; localparam PATTERN_1    = 7'b0000110;
localparam PATTERN_2    = 7'b1011011; localparam PATTERN_3    = 7'b1001111;
localparam PATTERN_4    = 7'b1100110; localparam PATTERN_5    = 7'b1101101;
localparam PATTERN_6    = 7'b1111101; localparam PATTERN_7    = 7'b0000111;
localparam PATTERN_BLANK= 7'b0000000;
localparam PATTERN_H    = 7'b1110110; // For '#' (Sharp sign) - looks like an H
localparam PATTERN_b    = 7'b1111100; // For 'b' (Flat sign) - lowercase b

// Octave display patterns (for SEG2)
localparam OCTAVE_UP_PATTERN    = 7'b0000001; // 'a' (or U for Up, H for High)
localparam OCTAVE_NORMAL_PATTERN= 7'b1000000; // 'g' (or M for Mid, - for normal)
localparam OCTAVE_DOWN_PATTERN  = 7'b0001000; // 'd' (or L for Low)

// Internal registers for decoded segment data for each display purpose
reg [6:0] seg_data_for_note_digit;    // For SEG1
reg [6:0] seg_data_for_semitone_suffix; // For SEG0
reg [6:0] seg_data_for_octave;        // For SEG2

// Decoder for Note Digit (SEG1)
always @(*) begin
    if (!display_active_flag) begin // If no valid note is active, SEG1 is blank
        seg_data_for_note_digit = PATTERN_BLANK;
    end else begin
        case (base_note_id_in)
            3'd1: seg_data_for_note_digit = PATTERN_1; 3'd2: seg_data_for_note_digit = PATTERN_2;
            3'd3: seg_data_for_note_digit = PATTERN_3; 3'd4: seg_data_for_note_digit = PATTERN_4;
            3'd5: seg_data_for_note_digit = PATTERN_5; 3'd6: seg_data_for_note_digit = PATTERN_6;
            3'd7: seg_data_for_note_digit = PATTERN_7;
            default: seg_data_for_note_digit = PATTERN_BLANK; // Includes base_note_id_in = 0
        endcase
    end
end

// Decoder for Semitone Suffix (SEG0)
always @(*) begin
    if (!display_active_flag) begin // If no valid note is active, SEG0 is blank
        seg_data_for_semitone_suffix = PATTERN_BLANK;
    end else begin
        case (semitone_type_in)
            2'b01:  seg_data_for_semitone_suffix = PATTERN_H;    // Sharp (#)
            2'b10:  seg_data_for_semitone_suffix = PATTERN_b;    // Flat (b)
            default: seg_data_for_semitone_suffix = PATTERN_BLANK; // Natural note, no suffix
        endcase
    end
end

// Decoder for Octave (SEG2) - This is always active
always @(*) begin
    if (octave_up_active && !octave_down_active) seg_data_for_octave = OCTAVE_UP_PATTERN;
    else if (!octave_up_active && octave_down_active) seg_data_for_octave = OCTAVE_DOWN_PATTERN;
    else seg_data_for_octave = OCTAVE_NORMAL_PATTERN; // Middle or both/neither octave keys pressed
end

// Muxing Logic for 3 digits: SEG0 (Suffix), SEG1 (Note Digit), SEG2 (Octave)
// We cycle through these three displays.
// Assuming refresh rate per digit around 60-100Hz. Total scan rate is 3x that.
// For ~5ms per digit illumination: 50MHz / (5ms) = 10,000 clocks -> 50MHz / 250_000_000 = 200 Hz display for each digit. 3 digits * 200Hz = 600 Hz for the whole cycle.
// 50_000_000 / 250_000 = 200 Hz refresh for one digit position if it were static.
// Each digit will be on for MUX_COUNT_MAX_PER_DIGIT cycles.
// Total cycle for 3 digits: 3 * MUX_COUNT_MAX_PER_DIGIT.
// Refresh rate for the set: CLK_FREQ / (3 * MUX_COUNT_MAX_PER_DIGIT).
// Target ~60Hz refresh: 50e6 / (3 * X) = 60  => X = 50e6 / 180 = ~277,777
localparam MUX_COUNT_MAX_PER_DIGIT = 250000; // ~5ms per digit display time, yields ~66Hz refresh for the group
reg [$clog2(MUX_COUNT_MAX_PER_DIGIT)-1:0] mux_counter_reg;
reg [1:0] current_display_slot_reg; // 00: SEG0 (Suffix), 01: SEG1 (Note Digit), 10: SEG2 (Octave)

initial begin
    seg_a = 1'b0; seg_b = 1'b0; seg_c = 1'b0; seg_d = 1'b0;
    seg_e = 1'b0; seg_f = 1'b0; seg_g = 1'b0; seg_dp = 1'b0;
    digit_selects = 8'h00; // All digits deselected (ACTIVE HIGH for your board's SEG0-7)
    mux_counter_reg = 0;
    current_display_slot_reg = 2'b00; // Start by displaying Suffix on SEG0
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mux_counter_reg <= 0;
        current_display_slot_reg <= 2'b00;
        digit_selects <= 8'h00; // All off
        seg_a <= 1'b0; seg_b <= 1'b0; seg_c <= 1'b0; seg_d <= 1'b0;
        seg_e <= 1'b0; seg_f <= 1'b0; seg_g <= 1'b0; seg_dp <= 1'b0;
    end else begin
        // Default: Turn off all segments and digit selects for this cycle, then selectively turn on.
        seg_a <= 1'b0; seg_b <= 1'b0; seg_c <= 1'b0; seg_d <= 1'b0;
        seg_e <= 1'b0; seg_f <= 1'b0; seg_g <= 1'b0; seg_dp <= 1'b0; // dp not used
        digit_selects <= 8'h00;

        // Advance to next display slot or reset counter
        if (mux_counter_reg >= MUX_COUNT_MAX_PER_DIGIT - 1) begin
            mux_counter_reg <= 0;
            if (current_display_slot_reg == 2'b10) begin // Was displaying Octave (SEG2)
                current_display_slot_reg <= 2'b00;     // Next is Suffix (SEG0)
            end else begin
                current_display_slot_reg <= current_display_slot_reg + 1'b1;
            end
        end else begin
            mux_counter_reg <= mux_counter_reg + 1;
        end

        // Drive the segments and select the active digit based on the current slot
        case (current_display_slot_reg)
            2'b00: begin // Display Semitone Suffix on SEG0 (Physical digit_selects[0] -> PIN_119)
                seg_g <= seg_data_for_semitone_suffix[6]; seg_f <= seg_data_for_semitone_suffix[5];
                seg_e <= seg_data_for_semitone_suffix[4]; seg_d <= seg_data_for_semitone_suffix[3];
                seg_c <= seg_data_for_semitone_suffix[2]; seg_b <= seg_data_for_semitone_suffix[1];
                seg_a <= seg_data_for_semitone_suffix[0];
                digit_selects[0] <= 1'b1; // Activate SEG0
            end
            2'b01: begin // Display Note Digit on SEG1 (Physical digit_selects[1] -> PIN_126)
                seg_g <= seg_data_for_note_digit[6]; seg_f <= seg_data_for_note_digit[5];
                seg_e <= seg_data_for_note_digit[4]; seg_d <= seg_data_for_note_digit[3];
                seg_c <= seg_data_for_note_digit[2]; seg_b <= seg_data_for_note_digit[1];
                seg_a <= seg_data_for_note_digit[0];
                digit_selects[1] <= 1'b1; // Activate SEG1
            end
            2'b10: begin // Display Octave on SEG2 (Physical digit_selects[2] -> PIN_115)
                seg_g <= seg_data_for_octave[6]; seg_f <= seg_data_for_octave[5];
                seg_e <= seg_data_for_octave[4]; seg_d <= seg_data_for_octave[3];
                seg_c <= seg_data_for_octave[2]; seg_b <= seg_data_for_octave[1];
                seg_a <= seg_data_for_octave[0];
                digit_selects[2] <= 1'b1; // Activate SEG2
            end
            default: digit_selects <= 8'h00; // Should not be reached, keep all off
        endcase
    end
end
endmodule