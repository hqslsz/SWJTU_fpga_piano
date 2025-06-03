// File: fpga_piano_top.v
// Top-level module for the FPGA Piano with recording and semitones

module fpga (
    // Clock and Reset
    input clk_50mhz,             // System clock (PIN_90)
    input sw0_physical_reset,    // Physical reset button (Key0/SW0, PIN_24, active HIGH press)

    // Musical Note Keys
    input [6:0] note_keys_physical_in, // Key1-Key7 (C,D,E,F,G,A,B)
                                       // PIN_31(K1), PIN_30(K2), PIN_33(K3), PIN_32(K4)
                                       // PIN_42(K5), PIN_39(K6), PIN_44(K7)

    // Semitone Keys (Key8-Key12)
    input key8_sharp1_raw,         // 1# (C#) - PIN_43 (SW8)
    input key9_flat3_raw,          // 3b (Eb) - PIN_13 (SW9)
    input key10_sharp4_raw,        // 4# (F#) - PIN_6  (SW10)
    input key11_sharp5_raw,        // 5# (G#) - PIN_144(SW11)
    input key12_flat7_raw,         // 7b (Bb) - PIN_8  (SW12)

    // Control Keys
    input sw15_octave_up_raw,    // Octave Up key (Key15/SW15, PIN_10)
    input sw13_octave_down_raw,  // Octave Down key (Key13/SW13, PIN_7)
    input sw16_record_raw,       // Record key (Key16/SW16, PIN_142)
    input sw17_playback_raw,     // Playback key (Key17/SW17, PIN_137)

    // Outputs
    output reg buzzer_out,       // Buzzer output (PIN_128)

    // Outputs for 7-Segment Display
    output seven_seg_a, output seven_seg_b, output seven_seg_c, output seven_seg_d,
    output seven_seg_e, output seven_seg_f, output seven_seg_g, output seven_seg_dp,
    output [7:0] seven_seg_digit_selects // For SEG0-SEG7
);

// --- Internal Reset Logic ---
wire rst_n_internal;
assign rst_n_internal = ~sw0_physical_reset; // Convert active high physical reset to active low internal

// --- Debouncer Parameter ---
localparam DEBOUNCE_TIME_MS = 20;
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000); // For 50MHz clock

// --- Consolidate All Musical Key Inputs ---
localparam NUM_BASE_KEYS = 7;
localparam NUM_SEMITONE_KEYS = 5;
localparam NUM_TOTAL_MUSICAL_KEYS = NUM_BASE_KEYS + NUM_SEMITONE_KEYS; // 7 + 5 = 12 keys

wire [NUM_TOTAL_MUSICAL_KEYS-1:0] all_musical_keys_raw;

// Assign base notes (Key ID 1 to 7)
assign all_musical_keys_raw[0] = note_keys_physical_in[0]; // Key1 (C) -> ID 1
assign all_musical_keys_raw[1] = note_keys_physical_in[1]; // Key2 (D) -> ID 2
assign all_musical_keys_raw[2] = note_keys_physical_in[2]; // Key3 (E) -> ID 3
assign all_musical_keys_raw[3] = note_keys_physical_in[3]; // Key4 (F) -> ID 4
assign all_musical_keys_raw[4] = note_keys_physical_in[4]; // Key5 (G) -> ID 5
assign all_musical_keys_raw[5] = note_keys_physical_in[5]; // Key6 (A) -> ID 6
assign all_musical_keys_raw[6] = note_keys_physical_in[6]; // Key7 (B) -> ID 7

// Assign semitone notes (Key ID 8 to 12)
assign all_musical_keys_raw[7] = key8_sharp1_raw;          // Key8 (C#) -> ID 8
assign all_musical_keys_raw[8] = key9_flat3_raw;           // Key9 (Eb) -> ID 9
assign all_musical_keys_raw[9] = key10_sharp4_raw;         // Key10 (F#) -> ID 10
assign all_musical_keys_raw[10] = key11_sharp5_raw;        // Key11 (G#) -> ID 11
assign all_musical_keys_raw[11] = key12_flat7_raw;         // Key12 (Bb) -> ID 12


// --- Keyboard Scanner Instance for ALL Musical Notes ---
// Output active_key_id will be 0 for no key, 1-12 for pressed keys.
// Needs $clog2(12+1) = 4 bits.
wire [3:0] current_active_key_id_internal;
wire       current_key_is_pressed_flag_internal;

keyboard_scanner #(
    .NUM_KEYS(NUM_TOTAL_MUSICAL_KEYS), // Set to 12
    .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS)
) keyboard_scanner_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .keys_in_raw(all_musical_keys_raw),
    .active_key_id(current_active_key_id_internal), // Output width will be 4-bit
    .key_is_pressed(current_key_is_pressed_flag_internal)
);

// --- Debouncers for Octave and Control Keys ---
wire sw15_octave_up_debounced_internal;
wire sw13_octave_down_debounced_internal;
wire sw16_record_debounced_internal;    // Debounced record key level
wire sw17_playback_debounced_internal;  // Debounced playback key level
wire sw17_playback_pulse_internal;      // Single pulse for playback start

debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) octave_up_debouncer_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw15_octave_up_raw),
    .key_out_debounced(sw15_octave_up_debounced_internal)
);
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) octave_down_debouncer_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw13_octave_down_raw),
    .key_out_debounced(sw13_octave_down_debounced_internal)
);
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) record_debouncer_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw16_record_raw),
    .key_out_debounced(sw16_record_debounced_internal)
);
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) playback_debouncer_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw17_playback_raw),
    .key_out_debounced(sw17_playback_debounced_internal)
);

// Generate a single pulse for playback start from the debounced level
reg sw17_playback_debounced_prev;
initial sw17_playback_debounced_prev = 1'b0;
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) sw17_playback_debounced_prev <= 1'b0;
    else sw17_playback_debounced_prev <= sw17_playback_debounced_internal;
end
assign sw17_playback_pulse_internal = sw17_playback_debounced_internal & ~sw17_playback_debounced_prev;


// --- Instantiate Piano Recorder ---
localparam RECORDER_KEY_ID_BITS = 4; // For key IDs 0-12
wire [RECORDER_KEY_ID_BITS-1:0] playback_key_id_feed;
wire playback_key_is_pressed_feed;
wire playback_octave_up_feed;
wire playback_octave_down_feed;
wire is_recording_status; // For potential LED indicator
wire is_playing_status;   // For potential LED indicator

piano_recorder #(
    .CLK_FREQ_HZ(50_000_000),
    .RECORD_INTERVAL_MS(20),      // Sample every 20ms
    .MAX_RECORD_SAMPLES(512),     // Approx 10.24 seconds of recording
    .KEY_ID_BITS(RECORDER_KEY_ID_BITS), // Set to 4
    .OCTAVE_BITS(2)               // 00:normal, 01:up, 10:down
) piano_recorder_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .record_active_level(sw16_record_debounced_internal),
    .playback_start_pulse(sw17_playback_pulse_internal),
    .live_key_id(current_active_key_id_internal), // 4-bit input
    .live_key_is_pressed(current_key_is_pressed_flag_internal),
    .live_octave_up(sw15_octave_up_debounced_internal),
    .live_octave_down(sw13_octave_down_debounced_internal),
    .playback_key_id(playback_key_id_feed),       // 4-bit output
    .playback_key_is_pressed(playback_key_is_pressed_feed),
    .playback_octave_up(playback_octave_up_feed),
    .playback_octave_down(playback_octave_down_feed),
    .is_recording(is_recording_status),
    .is_playing(is_playing_status)
);

// --- Buzzer and Display Input Selection Logic ---
// These signals will drive the buzzer and display, selected from live or playback.
wire [RECORDER_KEY_ID_BITS-1:0] final_key_id_for_sound_and_display;
wire final_key_is_pressed_for_sound_and_display;
wire final_octave_up_for_sound_and_display;
wire final_octave_down_for_sound_and_display;

assign final_key_id_for_sound_and_display         = is_playing_status ? playback_key_id_feed         : current_active_key_id_internal;
assign final_key_is_pressed_for_sound_and_display = is_playing_status ? playback_key_is_pressed_feed : current_key_is_pressed_flag_internal;
assign final_octave_up_for_sound_and_display      = is_playing_status ? playback_octave_up_feed      : sw15_octave_up_debounced_internal;
assign final_octave_down_for_sound_and_display    = is_playing_status ? playback_octave_down_feed    : sw13_octave_down_debounced_internal;


// --- Buzzer Frequency Generation ---
// Target counts for a 50MHz clock to produce semitone frequencies (half-period counts)
// Formula: COUNT = (50_000_000 / (2 * Freq_Hz))
localparam CNT_C4  = 17'd95566; // Key ID 1 (C4)
localparam CNT_CS4 = 17'd90194; // Key ID 8 (C#4/Db4)
localparam CNT_D4  = 17'd85135; // Key ID 2 (D4)
localparam CNT_DS4 = 17'd80346; // Key ID 9 (D#4/Eb4)
localparam CNT_E4  = 17'd75830; // Key ID 3 (E4)
localparam CNT_F4  = 17'd71569; // Key ID 4 (F4)
localparam CNT_FS4 = 17'd67569; // Key ID 10 (F#4/Gb4)
localparam CNT_G4  = 17'd63775; // Key ID 5 (G4)
localparam CNT_GS4 = 17'd60197; // Key ID 11 (G#4/Ab4)
localparam CNT_A4  = 17'd56817; // Key ID 6 (A4)
localparam CNT_AS4 = 17'd53627; // Key ID 12 (A#4/Bb4)
localparam CNT_B4  = 17'd50619; // Key ID 7 (B4)

reg [17:0] buzzer_counter_reg;      // Counter for PWM generation
reg [17:0] base_note_target_count;  // Target count for the base note (before octave adjustment)
reg [17:0] final_target_count_max;  // Final target count after octave adjustment

// Determine base_note_target_count based on the selected key ID
always @(*) begin
    case (final_key_id_for_sound_and_display) // Now a 4-bit input
        4'd1:    base_note_target_count = CNT_C4;
        4'd2:    base_note_target_count = CNT_D4;
        4'd3:    base_note_target_count = CNT_E4;
        4'd4:    base_note_target_count = CNT_F4;
        4'd5:    base_note_target_count = CNT_G4;
        4'd6:    base_note_target_count = CNT_A4;
        4'd7:    base_note_target_count = CNT_B4;
        // Semitones
        4'd8:    base_note_target_count = CNT_CS4; // C#
        4'd9:    base_note_target_count = CNT_DS4; // Eb
        4'd10:   base_note_target_count = CNT_FS4; // F#
        4'd11:   base_note_target_count = CNT_GS4; // G#
        4'd12:   base_note_target_count = CNT_AS4; // Bb
        default: base_note_target_count = CNT_C4; // Default for ID 0 or unexpected
    endcase
end

// Determine final_target_count_max based on octave selection
always @(*) begin
    if (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display) begin
        // Octave Up: frequency doubles, so count halves
        final_target_count_max = (base_note_target_count + 1) / 2 - 1; // +1/-1 for integer division precision
    end else if (!final_octave_up_for_sound_and_display && final_octave_down_for_sound_and_display) begin
        // Octave Down: frequency halves, so count doubles
        final_target_count_max = (base_note_target_count + 1) * 2 - 1;
    end else begin
        // Normal Octave
        final_target_count_max = base_note_target_count;
    end
end

// Buzzer output generation logic
initial begin
    buzzer_out = 1'b0;
    buzzer_counter_reg = 18'd0;
end

always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if (!rst_n_internal) begin
        buzzer_counter_reg <= 18'd0;
        buzzer_out <= 1'b0;
    end else begin
        if (final_key_is_pressed_for_sound_and_display) begin
            if (buzzer_counter_reg >= final_target_count_max) begin
                buzzer_counter_reg <= 18'd0;
                buzzer_out <= ~buzzer_out; // Toggle to create square wave
            end else begin
                buzzer_counter_reg <= buzzer_counter_reg + 1'b1;
            end
        end else begin
            // No key pressed, silence the buzzer
            buzzer_counter_reg <= 18'd0;
            buzzer_out <= 1'b0;
        end
    end
end
// --- End of Buzzer Logic ---


// --- Instantiate Seven Segment Controller ---
// For now, semitones (IDs 8-12) will show as blank on the 7-segment display
// as the controller is only set up for 1-7. We pass only the low 3 bits of the key ID.
seven_segment_controller seven_segment_display_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    // Pass only the lower 3 bits for key ID so 1-7 display correctly.
    // For IDs 8-12, this will result in 000, 001, etc., which will either be blank
    // or show 0, 1 etc. based on seven_segment_controller's default for invalid IDs.
    // Ideally, seven_segment_controller should map these to blank.
    .current_active_key_id(final_key_id_for_sound_and_display[2:0]),
    .current_key_is_pressed_flag(final_key_is_pressed_for_sound_and_display),
    .octave_up_active(final_octave_up_for_sound_and_display),
    .octave_down_active(final_octave_down_for_sound_and_display),

    // 7-Segment Outputs
    .seg_a(seven_seg_a), .seg_b(seven_seg_b), .seg_c(seven_seg_c), .seg_d(seven_seg_d),
    .seg_e(seven_seg_e), .seg_f(seven_seg_f), .seg_g(seven_seg_g), .seg_dp(seven_seg_dp),
    .digit_selects(seven_seg_digit_selects)
);

endmodule