// File: seven_segment_controller.v
module seven_segment_controller (
    input clk,                           // System clock (50MHz)
    input rst_n,                         // Active low reset

    input [2:0] current_active_key_id,     // 0 for none, 1-7 for musical keys
    input current_key_is_pressed_flag, // True if a musical key is pressed
    input octave_up_active,            // True if SW15 (octave up) is pressed
    input octave_down_active,          // True if SW13 (octave down) is pressed

    output reg seg_a, output reg seg_b, output reg seg_c, output reg seg_d,
    output reg seg_e, output reg seg_f, output reg seg_g, output reg seg_dp,
    output reg [7:0] digit_selects       // For SEG0-SEG7, ACTIVE HIGH
);

// Segment patterns for COMMON CATHODE (1=ON, 0=OFF) - These are correct.
localparam PATTERN_0    = 7'b0111111; localparam PATTERN_1    = 7'b0000110;
localparam PATTERN_2    = 7'b1011011; localparam PATTERN_3    = 7'b1001111;
localparam PATTERN_4    = 7'b1100110; localparam PATTERN_5    = 7'b1101101;
localparam PATTERN_6    = 7'b1111101; localparam PATTERN_7    = 7'b0000111;
localparam PATTERN_BLANK= 7'b0000000;

localparam OCTAVE_UP_PATTERN    = 7'b0000001; // 'a'
localparam OCTAVE_NORMAL_PATTERN= 7'b1000000; // 'g'
localparam OCTAVE_DOWN_PATTERN  = 7'b0001000; // 'd'

reg [6:0] seg_data_for_note;
reg [6:0] seg_data_for_octave;

always @(*) begin /* Note Decoder - Correct */
    if (!current_key_is_pressed_flag) seg_data_for_note = PATTERN_BLANK;
    else case (current_active_key_id)
        3'd1: seg_data_for_note = PATTERN_1; 3'd2: seg_data_for_note = PATTERN_2;
        3'd3: seg_data_for_note = PATTERN_3; 3'd4: seg_data_for_note = PATTERN_4;
        3'd5: seg_data_for_note = PATTERN_5; 3'd6: seg_data_for_note = PATTERN_6;
        3'd7: seg_data_for_note = PATTERN_7; default: seg_data_for_note = PATTERN_BLANK;
    endcase
end
always @(*) begin /* Octave Decoder - Correct */
    if (octave_up_active && !octave_down_active) seg_data_for_octave = OCTAVE_UP_PATTERN;
    else if (!octave_up_active && octave_down_active) seg_data_for_octave = OCTAVE_DOWN_PATTERN;
    else seg_data_for_octave = OCTAVE_NORMAL_PATTERN;
end

localparam MUX_COUNT_MAX = 250000; // ~5ms per digit
reg [18:0] mux_counter;
// current_timeslot_is_for_seg1:
// TRUE means it's time to drive Physical SEG1 (digit_selects[1], PIN_126) which should show NOTE.
// FALSE means it's time to drive Physical SEG2 (digit_selects[2], PIN_115) which should show OCTAVE.
reg current_timeslot_is_for_seg1;

initial begin // Correct for Active HIGH digit select
    seg_a = 0; seg_b = 0; seg_c = 0; seg_d = 0; seg_e = 0; seg_f = 0; seg_g = 0; seg_dp = 0;
    digit_selects = 8'h00; // All digits deselected (ACTIVE HIGH)
    mux_counter = 0;
    current_timeslot_is_for_seg1 = 1'b1; // Start with SEG1 (Note)
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // Correct reset for Active HIGH
        mux_counter <= 0;
        current_timeslot_is_for_seg1 <= 1'b1;
        digit_selects <= 8'h00;
        seg_a <= 0; seg_b <= 0; seg_c <= 0; seg_d <= 0; seg_e <= 0; seg_f <= 0; seg_g <= 0; seg_dp <= 0;
    end else begin
        // Default to all segments OFF and all digits deselected (ACTIVE HIGH) - Correct
        seg_a <= 0; seg_b <= 0; seg_c <= 0; seg_d <= 0; seg_e <= 0; seg_f <= 0; seg_g <= 0; seg_dp <= 0;
        digit_selects <= 8'h00;

        if (mux_counter == MUX_COUNT_MAX - 1) begin
            mux_counter <= 0;
            current_timeslot_is_for_seg1 <= ~current_timeslot_is_for_seg1;
        end else begin
            mux_counter <= mux_counter + 1;
        end

        // CORRECTED DATA ASSIGNMENT TO MATCH YOUR GOAL:
        // Physical SEG1 (digit_selects[1] = PIN_126) should display NOTE.
        // Physical SEG2 (digit_selects[2] = PIN_115) should display OCTAVE.
        if (current_timeslot_is_for_seg1) begin // Time slot for Physical SEG1 (to display NOTE)
            seg_g <= seg_data_for_note[6]; seg_f <= seg_data_for_note[5];
            seg_e <= seg_data_for_note[4]; seg_d <= seg_data_for_note[3];
            seg_c <= seg_data_for_note[2]; seg_b <= seg_data_for_note[1];
            seg_a <= seg_data_for_note[0];
            digit_selects[1] <= 1'b1; // Activate physical SEG1 (PIN_126)
        end else begin // Time slot for Physical SEG2 (to display OCTAVE)
            seg_g <= seg_data_for_octave[6]; seg_f <= seg_data_for_octave[5];
            seg_e <= seg_data_for_octave[4]; seg_d <= seg_data_for_octave[3];
            seg_c <= seg_data_for_octave[2]; seg_b <= seg_data_for_octave[1];
            seg_a <= seg_data_for_octave[0];
            digit_selects[2] <= 1'b1; // Activate physical SEG2 (PIN_115)
        end
    end
end
endmodule