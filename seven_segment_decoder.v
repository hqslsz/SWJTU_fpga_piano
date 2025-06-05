// File: seven_segment_controller.v
// Modified to display:
// - SEG0: Current Semitone Suffix (#/b)
// - SEG1-SEG6: Scrolled Note Digits (from scrolling_display_buffer)
// - SEG7: Octave Status
module seven_segment_controller (
    input clk,
    input rst_n,

    // Inputs for SEG0 (Suffix)
    input [1:0] semitone_type_in,        // 00: none, 01: sharp (#), 10: flat (b)
    input semitone_display_active_flag,  // True if a valid musical note is active for SEG0 suffix display

    // Inputs for SEG1-SEG6 (Scrolled Note Digits from buffer)
    // Each input is [2:0], 0 for blank, 1-7 for note.
    input [2:0] scrolled_note_seg1_in,
    input [2:0] scrolled_note_seg2_in,
    input [2:0] scrolled_note_seg3_in,
    input [2:0] scrolled_note_seg4_in,
    input [2:0] scrolled_note_seg5_in,
    input [2:0] scrolled_note_seg6_in,

    // Inputs for SEG7 (Octave)
    input octave_up_active,
    input octave_down_active,

    output reg seg_a, output reg seg_b, output reg seg_c, output reg seg_d,
    output reg seg_e, output reg seg_f, output reg seg_g, output reg seg_dp,
    output reg [7:0] digit_selects
);

// Segment patterns (same as before)
localparam PATTERN_0    = 7'b0111111; localparam PATTERN_1    = 7'b0000110;
localparam PATTERN_2    = 7'b1011011; localparam PATTERN_3    = 7'b1001111;
localparam PATTERN_4    = 7'b1100110; localparam PATTERN_5    = 7'b1101101;
localparam PATTERN_6    = 7'b1111101; localparam PATTERN_7    = 7'b0000111;
localparam PATTERN_BLANK= 7'b0000000;
localparam PATTERN_H    = 7'b1110110; // For '#'
localparam PATTERN_b    = 7'b1111100; // For 'b'

localparam OCTAVE_UP_PATTERN    = 7'b0000001; // 'a'
localparam OCTAVE_NORMAL_PATTERN= 7'b1000000; // 'g'
localparam OCTAVE_DOWN_PATTERN  = 7'b0001000; // 'd'

// Decoded segment data for each display position
reg [6:0] seg_data_suffix;     // For SEG0
reg [6:0] seg_data_scrolled_notes [1:6]; // Array for SEG1-SEG6 data
reg [6:0] seg_data_octave;     // For SEG7

// Combinational logic to decode note ID to segment pattern
function [6:0] decode_note_to_segments (input [2:0] note_id);
    case (note_id)
        3'd1: decode_note_to_segments = PATTERN_1; 3'd2: decode_note_to_segments = PATTERN_2;
        3'd3: decode_note_to_segments = PATTERN_3; 3'd4: decode_note_to_segments = PATTERN_4;
        3'd5: decode_note_to_segments = PATTERN_5; 3'd6: decode_note_to_segments = PATTERN_6;
        3'd7: decode_note_to_segments = PATTERN_7;
        default: decode_note_to_segments = PATTERN_BLANK; // Includes 0
    endcase
endfunction

// Decoder for Semitone Suffix (SEG0)
always @(*) begin
    if (!semitone_display_active_flag) seg_data_suffix = PATTERN_BLANK;
    else case (semitone_type_in)
        2'b01:  seg_data_suffix = PATTERN_H;
        2'b10:  seg_data_suffix = PATTERN_b;
        default: seg_data_suffix = PATTERN_BLANK;
    endcase
end

// Decoder for Scrolled Notes (SEG1-SEG6)
integer k;
always @(*) begin
    seg_data_scrolled_notes[1] = decode_note_to_segments(scrolled_note_seg1_in);
    seg_data_scrolled_notes[2] = decode_note_to_segments(scrolled_note_seg2_in);
    seg_data_scrolled_notes[3] = decode_note_to_segments(scrolled_note_seg3_in);
    seg_data_scrolled_notes[4] = decode_note_to_segments(scrolled_note_seg4_in);
    seg_data_scrolled_notes[5] = decode_note_to_segments(scrolled_note_seg5_in);
    seg_data_scrolled_notes[6] = decode_note_to_segments(scrolled_note_seg6_in);
end

// Decoder for Octave (SEG7)
always @(*) begin
    if (octave_up_active && !octave_down_active) seg_data_octave = OCTAVE_UP_PATTERN;
    else if (!octave_up_active && octave_down_active) seg_data_octave = OCTAVE_DOWN_PATTERN;
    else seg_data_octave = OCTAVE_NORMAL_PATTERN;
end

// Muxing Logic for 8 digits (SEG0 to SEG7)
localparam NUM_DISPLAY_SLOTS = 8;
localparam MUX_COUNT_MAX_PER_DIGIT = 104000; // Approx 2.08ms per digit, ~60Hz group refresh

reg [$clog2(MUX_COUNT_MAX_PER_DIGIT)-1:0] mux_counter_reg;
reg [2:0] current_digit_slot_reg;

initial begin
    // ... (same initial block as before) ...
    seg_a = 1'b0; seg_b = 1'b0; seg_c = 1'b0; seg_d = 1'b0;
    seg_e = 1'b0; seg_f = 1'b0; seg_g = 1'b0; seg_dp = 1'b0;
    digit_selects = 8'h00;
    mux_counter_reg = 0;
    current_digit_slot_reg = 3'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // ... (same reset logic as before) ...
        mux_counter_reg <= 0;
        current_digit_slot_reg <= 3'd0;
        digit_selects <= 8'h00;
        seg_a <= 1'b0; seg_b <= 1'b0; seg_c <= 1'b0; seg_d <= 1'b0;
        seg_e <= 1'b0; seg_f <= 1'b0; seg_g <= 1'b0; seg_dp <= 1'b0;
    end else begin
        seg_a <= 1'b0; seg_b <= 1'b0; seg_c <= 1'b0; seg_d <= 1'b0;
        seg_e <= 1'b0; seg_f <= 1'b0; seg_g <= 1'b0; seg_dp <= 1'b0;
        digit_selects <= 8'h00;

        if (mux_counter_reg >= MUX_COUNT_MAX_PER_DIGIT - 1) begin
            mux_counter_reg <= 0;
            current_digit_slot_reg <= (current_digit_slot_reg == NUM_DISPLAY_SLOTS - 1) ? 3'd0 : current_digit_slot_reg + 1'b1;
        end else begin
            mux_counter_reg <= mux_counter_reg + 1;
        end

        // ... inside the always @(posedge clk or negedge rst_n) block ...
// ... inside the 'else' branch ...
        case (current_digit_slot_reg)
            3'd0: begin // SEG0: Semitone Suffix
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_suffix; // CHANGED TO <=
                digit_selects[0] <= 1'b1; // Keep as is, or assign digit_selects as a whole
            end
            3'd1: begin // SEG1: Scrolled Note 1
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[1]; // CHANGED TO <=
                digit_selects[1] <= 1'b1;
            end
            3'd2: begin // SEG2: Scrolled Note 2
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[2]; // CHANGED TO <=
                digit_selects[2] <= 1'b1;
            end
            3'd3: begin // SEG3: Scrolled Note 3
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[3]; // CHANGED TO <=
                digit_selects[3] <= 1'b1;
            end
            3'd4: begin // SEG4: Scrolled Note 4
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[4]; // CHANGED TO <=
                digit_selects[4] <= 1'b1;
            end
            3'd5: begin // SEG5: Scrolled Note 5
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[5]; // CHANGED TO <=
                digit_selects[5] <= 1'b1;
            end
            3'd6: begin // SEG6: Scrolled Note 6
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[6]; // CHANGED TO <=
                digit_selects[6] <= 1'b1;
            end
            3'd7: begin // SEG7: Octave Status
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_octave; // CHANGED TO <=
                digit_selects[7] <= 1'b1;
            end
            default: digit_selects <= 8'h00;
        endcase
// ...
    end
end
endmodule