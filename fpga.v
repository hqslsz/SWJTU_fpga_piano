// File: fpga_piano_top.v
module fpga (
    input clk_50mhz,             // System clock (PIN_90)
    input sw0_physical_reset,    // Physical reset button (Key0/SW0, PIN_24, active HIGH press)

    input [6:0] note_keys_physical_in, // Key1-Key7 (PIN_31,30,33,32,42,39,44)

    input sw15_octave_up_raw,    // Octave Up key (Key15/SW15, PIN_10)
    input sw13_octave_down_raw,  // Octave Down key (Key13/SW13, PIN_7)

    output reg buzzer_out,       // Buzzer output (PIN_128)

    // Outputs for 7-Segment Display
    output seven_seg_a, output seven_seg_b, output seven_seg_c, output seven_seg_d,
    output seven_seg_e, output seven_seg_f, output seven_seg_g, output seven_seg_dp,
    output [7:0] seven_seg_digit_selects // For SEG0-SEG7
);

// --- Internal Reset Logic ---
wire rst_n_internal;
assign rst_n_internal = ~sw0_physical_reset;

// --- Debouncer Parameter ---
localparam DEBOUNCE_TIME_MS = 20;
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000);

// --- Keyboard Scanner Instance for Musical Notes ---
localparam NUM_MUSICAL_KEYS = 7;
wire [2:0] current_active_key_id_internal;
wire current_key_is_pressed_flag_internal;

keyboard_scanner #(
    .NUM_KEYS(NUM_MUSICAL_KEYS),
    .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS)
) keyboard_scanner_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .keys_in_raw(note_keys_physical_in),
    .active_key_id(current_active_key_id_internal),
    .key_is_pressed(current_key_is_pressed_flag_internal)
);

// --- Debouncers for Octave Keys ---
wire sw15_octave_up_debounced_internal;
wire sw13_octave_down_debounced_internal;

debouncer #(
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC)
) octave_up_debouncer_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .key_in_raw(sw15_octave_up_raw),
    .key_out_debounced(sw15_octave_up_debounced_internal)
);

debouncer #(
    .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC)
) octave_down_debouncer_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .key_in_raw(sw13_octave_down_raw),
    .key_out_debounced(sw13_octave_down_debounced_internal)
);

// --- Buzzer Frequency Generation (Copied from previous, no change here) ---
localparam CNT_C4 = 17'd95566; localparam CNT_D4 = 17'd85135;
localparam CNT_E4 = 17'd75830; localparam CNT_F4 = 17'd71569;
localparam CNT_G4 = 17'd63775; localparam CNT_A4 = 17'd56817;
localparam CNT_B4 = 17'd50619;
reg [17:0] buzzer_counter_reg;
reg [17:0] base_note_target_count;
reg [17:0] final_target_count_max;
always @(*) begin /* base_note_target_count logic */
    case (current_active_key_id_internal)
        3'd1:    base_note_target_count = CNT_C4; 3'd2:    base_note_target_count = CNT_D4;
        3'd3:    base_note_target_count = CNT_E4; 3'd4:    base_note_target_count = CNT_F4;
        3'd5:    base_note_target_count = CNT_G4; 3'd6:    base_note_target_count = CNT_A4;
        3'd7:    base_note_target_count = CNT_B4; default: base_note_target_count = CNT_C4;
    endcase
end
always @(*) begin /* final_target_count_max logic */
    if (sw15_octave_up_debounced_internal && !sw13_octave_down_debounced_internal) begin
        final_target_count_max = (base_note_target_count + 1) / 2 - 1;
    end else if (!sw15_octave_up_debounced_internal && sw13_octave_down_debounced_internal) begin
        final_target_count_max = (base_note_target_count + 1) * 2 - 1;
    end else begin
        final_target_count_max = base_note_target_count;
    end
end
initial begin buzzer_out = 1'b0; buzzer_counter_reg = 18'd0; end
always @(posedge clk_50mhz or negedge rst_n_internal) begin /* buzzer output logic */
    if (!rst_n_internal) begin buzzer_counter_reg <= 18'd0; buzzer_out <= 1'b0;
    end else begin
        if (current_key_is_pressed_flag_internal) begin
            if (buzzer_counter_reg >= final_target_count_max) begin
                buzzer_counter_reg <= 18'd0; buzzer_out <= ~buzzer_out;
            end else begin buzzer_counter_reg <= buzzer_counter_reg + 1'b1; end
        end else begin buzzer_counter_reg <= 18'd0; buzzer_out <= 1'b0; end
    end
end
// --- End of Buzzer Logic ---

// --- Instantiate Seven Segment Controller ---
seven_segment_controller seven_segment_display_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .current_active_key_id(current_active_key_id_internal),
    .current_key_is_pressed_flag(current_key_is_pressed_flag_internal),
    .octave_up_active(sw15_octave_up_debounced_internal),
    .octave_down_active(sw13_octave_down_debounced_internal),

    .seg_a(seven_seg_a), .seg_b(seven_seg_b), .seg_c(seven_seg_c), .seg_d(seven_seg_d),
    .seg_e(seven_seg_e), .seg_f(seven_seg_f), .seg_g(seven_seg_g), .seg_dp(seven_seg_dp),
    .digit_selects(seven_seg_digit_selects)
);

endmodule