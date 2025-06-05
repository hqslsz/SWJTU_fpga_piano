// File: fpga.v (Modified for song player octave support)
// Top-level module for the FPGA Piano with recording, semitones, and song playback with octaves

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
    input key14_play_song_raw,   // Play Song key (Key14/SW14, PIN_11)

    // Outputs
    output reg buzzer_out,       // Buzzer output (PIN_128)

    // Outputs for 7-Segment Display
    output seven_seg_a, output seven_seg_b, output seven_seg_c, output seven_seg_d,
    output seven_seg_e, output seven_seg_f, output seven_seg_g, output seven_seg_dp,
    output [7:0] seven_seg_digit_selects// For SEG0-SEG7

    // Optional LED Outputs (uncomment and assign pins if used)
    // output led_is_recording,
    // output led_is_playing_recording,
    // output led_is_playing_song
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

assign all_musical_keys_raw[0] = note_keys_physical_in[0]; // Key1 (C) -> ID 1
assign all_musical_keys_raw[1] = note_keys_physical_in[1]; // Key2 (D) -> ID 2
assign all_musical_keys_raw[2] = note_keys_physical_in[2]; // Key3 (E) -> ID 3
assign all_musical_keys_raw[3] = note_keys_physical_in[3]; // Key4 (F) -> ID 4
assign all_musical_keys_raw[4] = note_keys_physical_in[4]; // Key5 (G) -> ID 5
assign all_musical_keys_raw[5] = note_keys_physical_in[5]; // Key6 (A) -> ID 6
assign all_musical_keys_raw[6] = note_keys_physical_in[6]; // Key7 (B) -> ID 7
assign all_musical_keys_raw[7] = key8_sharp1_raw;          // Key8 (C#) -> ID 8
assign all_musical_keys_raw[8] = key9_flat3_raw;           // Key9 (Eb) -> ID 9
assign all_musical_keys_raw[9] = key10_sharp4_raw;         // Key10 (F#) -> ID 10
assign all_musical_keys_raw[10] = key11_sharp5_raw;        // Key11 (G#) -> ID 11
assign all_musical_keys_raw[11] = key12_flat7_raw;         // Key12 (Bb) -> ID 12


// --- Keyboard Scanner Instance for ALL Musical Notes ---
wire [3:0] current_active_key_id_internal; // For 12 keys + no key (0), needs 4 bits
wire       current_key_is_pressed_flag_internal;

keyboard_scanner #(
    .NUM_KEYS(NUM_TOTAL_MUSICAL_KEYS),
    .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS)
) keyboard_scanner_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .keys_in_raw(all_musical_keys_raw),
    .active_key_id(current_active_key_id_internal),
    .key_is_pressed(current_key_is_pressed_flag_internal)
);

// --- Debouncers for Octave and Control Keys ---
wire sw15_octave_up_debounced_internal;
wire sw13_octave_down_debounced_internal;
wire sw16_record_debounced_internal;
wire sw17_playback_debounced_internal;
wire sw17_playback_pulse_internal;
wire key14_play_song_debounced_internal;

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
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) play_song_debouncer_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(key14_play_song_raw),
    .key_out_debounced(key14_play_song_debounced_internal)
);

// Generate a single pulse for playback start (for piano_recorder)
reg sw17_playback_debounced_prev;
initial sw17_playback_debounced_prev = 1'b0;
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) sw17_playback_debounced_prev <= 1'b0;
    else sw17_playback_debounced_prev <= sw17_playback_debounced_internal;
end
assign sw17_playback_pulse_internal = sw17_playback_debounced_internal & ~sw17_playback_debounced_prev;

// --- Instantiate Piano Recorder ---
localparam RECORDER_KEY_ID_BITS = 4; // Must be 4 for 0-12 keys
localparam RECORDER_OCTAVE_BITS = 2; // For low, mid, high recording

wire [RECORDER_KEY_ID_BITS-1:0] playback_key_id_feed;
wire playback_key_is_pressed_feed;
wire playback_octave_up_feed;
wire playback_octave_down_feed;
wire is_recording_status;
wire is_playing_status; // From piano_recorder

piano_recorder #(
    .CLK_FREQ_HZ(50_000_000),
    .RECORD_INTERVAL_MS(20),
    .MAX_RECORD_SAMPLES(512),
    .KEY_ID_BITS(RECORDER_KEY_ID_BITS),
    .OCTAVE_BITS(RECORDER_OCTAVE_BITS) // Use defined parameter
) piano_recorder_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .record_active_level(sw16_record_debounced_internal),
    .playback_start_pulse(sw17_playback_pulse_internal),
    .live_key_id(current_active_key_id_internal),
    .live_key_is_pressed(current_key_is_pressed_flag_internal),
    .live_octave_up(sw15_octave_up_debounced_internal),
    .live_octave_down(sw13_octave_down_debounced_internal),
    .playback_key_id(playback_key_id_feed),
    .playback_key_is_pressed(playback_key_is_pressed_feed),
    .playback_octave_up(playback_octave_up_feed),
    .playback_octave_down(playback_octave_down_feed),
    .is_recording(is_recording_status),
    .is_playing(is_playing_status)
);

// --- Instantiate Song Player ---
wire [RECORDER_KEY_ID_BITS-1:0] song_player_key_id_feed;
wire song_player_key_is_pressed_feed;
wire song_player_octave_up_internal;    // New wire for song's octave up
wire song_player_octave_down_internal;  // New wire for song's octave down
wire is_song_playing_status;

song_player #(
    .CLK_FREQ_HZ(50_000_000),
    .KEY_ID_BITS(RECORDER_KEY_ID_BITS), // Match recorder's key ID bits
    .OCTAVE_BITS(RECORDER_OCTAVE_BITS)  // Match recorder's octave bits for consistency
) song_player_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .play_active_level(key14_play_song_debounced_internal),
    .song_key_id(song_player_key_id_feed),
    .song_key_is_pressed(song_player_key_is_pressed_feed),
    .song_octave_up_feed(song_player_octave_up_internal),     // Connect to new output
    .song_octave_down_feed(song_player_octave_down_internal), // Connect to new output
    .is_song_playing(is_song_playing_status)
);

// --- Buzzer and Display Input Selection Logic ---
wire [RECORDER_KEY_ID_BITS-1:0] final_key_id_for_sound_and_display;
wire final_key_is_pressed_for_sound_and_display;
wire final_octave_up_for_sound_and_display;
wire final_octave_down_for_sound_and_display;

assign final_key_id_for_sound_and_display =
    is_song_playing_status ? song_player_key_id_feed :
    (is_playing_status ? playback_key_id_feed :
    current_active_key_id_internal);

assign final_key_is_pressed_for_sound_and_display =
    is_song_playing_status ? song_player_key_is_pressed_feed :
    (is_playing_status ? playback_key_is_pressed_feed :
    current_key_is_pressed_flag_internal);

// MODIFIED Octave Selection: Song player now dictates octave during its playback
assign final_octave_up_for_sound_and_display =
    is_song_playing_status ? song_player_octave_up_internal : // Use song's octave up
    (is_playing_status ? playback_octave_up_feed :
    sw15_octave_up_debounced_internal);

assign final_octave_down_for_sound_and_display =
    is_song_playing_status ? song_player_octave_down_internal : // Use song's octave down
    (is_playing_status ? playback_octave_down_feed :
    sw13_octave_down_debounced_internal);

// --- Buzzer Frequency Generation ---
// These are counts for half period for Middle C (C4) Octave
// N_half_period_counts = (50_000_000 Hz / (2 * F_note)) - 1
localparam CNT_C4  = 17'd95566; // 261.63 Hz
localparam CNT_CS4 = 17'd90194; // 277.18 Hz
localparam CNT_D4  = 17'd85135; // 293.66 Hz
localparam CNT_DS4 = 17'd80346; // 311.13 Hz (Eb)
localparam CNT_E4  = 17'd75830; // 329.63 Hz
localparam CNT_F4  = 17'd71569; // 349.23 Hz
localparam CNT_FS4 = 17'd67569; // 369.99 Hz
localparam CNT_G4  = 17'd63775; // 392.00 Hz
localparam CNT_GS4 = 17'd60197; // 415.30 Hz (Ab)
localparam CNT_A4  = 17'd56817; // 440.00 Hz
localparam CNT_AS4 = 17'd53627; // 466.16 Hz (Bb)
localparam CNT_B4  = 17'd50619; // 493.88 Hz

reg [17:0] buzzer_counter_reg;
reg [17:0] base_note_target_count;    // Target count for middle octave (C4 based)
reg [17:0] final_target_count_max; // Final target after octave adjustment

// Determine base note target count from key ID (middle octave reference)
always @(*) begin
    case (final_key_id_for_sound_and_display) // final_key_id is 4 bits (0-12)
        4'd1:    base_note_target_count = CNT_C4;
        4'd2:    base_note_target_count = CNT_D4;
        4'd3:    base_note_target_count = CNT_E4;
        4'd4:    base_note_target_count = CNT_F4;
        4'd5:    base_note_target_count = CNT_G4;
        4'd6:    base_note_target_count = CNT_A4;
        4'd7:    base_note_target_count = CNT_B4;
        4'd8:    base_note_target_count = CNT_CS4; // C#
        4'd9:    base_note_target_count = CNT_DS4; // D# (Eb)
        4'd10:   base_note_target_count = CNT_FS4; // F#
        4'd11:   base_note_target_count = CNT_GS4; // G# (Ab)
        4'd12:   base_note_target_count = CNT_AS4; // A# (Bb)
        default: base_note_target_count = 18'h3FFFF; // Effectively silent (very low freq or ensure buzzer_out stays low)
                                                    // Or use a very high count if 0 should be silent.
                                                    // CNT_C4 is ~95k, so 2^18-1 is much higher -> lower freq.
                                                    // Let's stick to a known high value for silence if key_id is 0.
    endcase
end

// Adjust target count based on octave signals
always @(*) begin
    // Ensure base_note_target_count is valid before division
    // If base_note_target_count could be very small or zero from a default case,
    // this could be an issue. Given our CNT values, it's fine.
    if (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display) begin // Octave Up
        // Target count for half period is halved (approx), so frequency doubles.
        // (N+1)/2 - 1 for new count, where N is old count.
        final_target_count_max = (base_note_target_count + 1) / 2 - 1;
    end else if (!final_octave_up_for_sound_and_display && final_octave_down_for_sound_and_display) begin // Octave Down
        // Target count for half period is doubled (approx), so frequency halves.
        // (N+1)*2 - 1 for new count.
        final_target_count_max = (base_note_target_count + 1) * 2 - 1;
    end else begin // Middle Octave (or both octave keys pressed - treat as middle)
        final_target_count_max = base_note_target_count;
    end
end

initial begin
    buzzer_out = 1'b0;
    buzzer_counter_reg = 18'd0;
end

always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if (!rst_n_internal) begin
        buzzer_counter_reg <= 18'd0;
        buzzer_out <= 1'b0;
    end else begin
        // Only generate sound if a key is considered pressed and it's not the REST note (ID 0)
        if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin
            if (buzzer_counter_reg >= final_target_count_max) begin
                buzzer_counter_reg <= 18'd0;
                buzzer_out <= ~buzzer_out;
            end else begin
                buzzer_counter_reg <= buzzer_counter_reg + 1'b1;
            end
        end else begin
            buzzer_counter_reg <= 18'd0; // Reset counter when no valid key is pressed
            buzzer_out <= 1'b0;          // Ensure silence
        end
    end
end

// --- Instantiate Seven Segment Controller ---
// Note: seven_segment_controller currently takes [2:0] for key_id,
// which is only 0-7. If you want to display semitones or more info,
// this module will need changes. For now, it will truncate the key ID.
// Consider how to display C# (ID 8) etc.
// A simple way: display 'C' for C#, 'd' for D#, etc., or use a dot.
// For now, passing the lower 3 bits for basic 1-7 display.
wire [2:0] display_key_id_truncated;
// Example: C#(8)->1, D#(9)->2, F#(10)->4, G#(11)->5, A#(12)->6
// This mapping helps show the root note on the 1-7 display.
// You can make this more sophisticated.
assign display_key_id_truncated =
    (final_key_id_for_sound_and_display == 4'd8)  ? 3'd1 : // C# -> 1 (C)
    (final_key_id_for_sound_and_display == 4'd9)  ? 3'd2 : // D# (Eb) -> 2 (D)
    (final_key_id_for_sound_and_display == 4'd10) ? 3'd4 : // F# -> 4 (F)
    (final_key_id_for_sound_and_display == 4'd11) ? 3'd5 : // G# (Ab) -> 5 (G)
    (final_key_id_for_sound_and_display == 4'd12) ? 3'd6 : // A# (Bb) -> 6 (A)
    (final_key_id_for_sound_and_display >= 4'd1 && final_key_id_for_sound_and_display <= 4'd7) ? final_key_id_for_sound_and_display[2:0] :
    3'd0; // Default to 0 (blank) if not a standard note or defined semitone

seven_segment_controller seven_segment_display_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .current_active_key_id(display_key_id_truncated), // Pass truncated/mapped ID
    .current_key_is_pressed_flag(final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0), // Only show if valid note
    .octave_up_active(final_octave_up_for_sound_and_display),
    .octave_down_active(final_octave_down_for_sound_and_display),

    .seg_a(seven_seg_a), .seg_b(seven_seg_b), .seg_c(seven_seg_c), .seg_d(seven_seg_d),
    .seg_e(seven_seg_e), .seg_f(seven_seg_f), .seg_g(seven_seg_g), .seg_dp(seven_seg_dp),
    .digit_selects(seven_seg_digit_selects)
);

// --- Optional LED Indicators ---
// assign led_is_recording = is_recording_status;
// assign led_is_playing_recording = is_playing_status && !is_song_playing_status; // Only recording playback
// assign led_is_playing_song = is_song_playing_status;

endmodule