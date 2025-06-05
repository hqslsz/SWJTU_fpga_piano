// File: fpga.v (Corrected: display signals are now reg type for procedural assignment)
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
    output [7:0] seven_seg_digit_selects // For SEG0-SEG7 (we'll use [0],[1],[2])

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
    .OCTAVE_BITS(RECORDER_OCTAVE_BITS)
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
wire song_player_octave_up_internal;
wire song_player_octave_down_internal;
wire is_song_playing_status;

song_player #(
    .CLK_FREQ_HZ(50_000_000),
    .KEY_ID_BITS(RECORDER_KEY_ID_BITS),
    .OCTAVE_BITS(RECORDER_OCTAVE_BITS)
) song_player_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .play_active_level(key14_play_song_debounced_internal),
    .song_key_id(song_player_key_id_feed),
    .song_key_is_pressed(song_player_key_is_pressed_feed),
    .song_octave_up_feed(song_player_octave_up_internal),
    .song_octave_down_feed(song_player_octave_down_internal),
    .is_song_playing(is_song_playing_status)
);

// --- Buzzer and Display Input Selection Logic (Multiplexer for Sound/Display Source) ---
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

assign final_octave_up_for_sound_and_display =
    is_song_playing_status ? song_player_octave_up_internal :
    (is_playing_status ? playback_octave_up_feed :
    sw15_octave_up_debounced_internal);

assign final_octave_down_for_sound_and_display =
    is_song_playing_status ? song_player_octave_down_internal :
    (is_playing_status ? playback_octave_down_feed :
    sw13_octave_down_debounced_internal);

// --- Buzzer Frequency Generation ---
localparam CNT_C4  = 17'd95566; localparam CNT_CS4 = 17'd90194; // C, C#
localparam CNT_D4  = 17'd85135; localparam CNT_DS4 = 17'd80346; // D, D# (Eb)
localparam CNT_E4  = 17'd75830;                                // E
localparam CNT_F4  = 17'd71569; localparam CNT_FS4 = 17'd67569; // F, F#
localparam CNT_G4  = 17'd63775; localparam CNT_GS4 = 17'd60197; // G, G# (Ab)
localparam CNT_A4  = 17'd56817; localparam CNT_AS4 = 17'd53627; // A, A# (Bb)
localparam CNT_B4  = 17'd50619;                                // B

reg [17:0] buzzer_counter_reg;
reg [17:0] base_note_target_count;
reg [17:0] final_target_count_max;

always @(*) begin // Determine base note target count (middle octave reference)
    case (final_key_id_for_sound_and_display)
        4'd1:  base_note_target_count = CNT_C4;  4'd8:  base_note_target_count = CNT_CS4;
        4'd2:  base_note_target_count = CNT_D4;  4'd9:  base_note_target_count = CNT_DS4;
        4'd3:  base_note_target_count = CNT_E4;
        4'd4:  base_note_target_count = CNT_F4;  4'd10: base_note_target_count = CNT_FS4;
        4'd5:  base_note_target_count = CNT_G4;  4'd11: base_note_target_count = CNT_GS4;
        4'd6:  base_note_target_count = CNT_A4;  4'd12: base_note_target_count = CNT_AS4;
        4'd7:  base_note_target_count = CNT_B4;
        default: base_note_target_count = 18'h3FFFF; // Effectively silent
    endcase
end

always @(*) begin // Adjust target count based on octave signals
    if (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display) begin // Octave Up
        final_target_count_max = (base_note_target_count + 1) / 2 - 1;
    end else if (!final_octave_up_for_sound_and_display && final_octave_down_for_sound_and_display) begin // Octave Down
        final_target_count_max = (base_note_target_count + 1) * 2 - 1;
    end else begin // Middle Octave
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
        if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin
            if (buzzer_counter_reg >= final_target_count_max) begin
                buzzer_counter_reg <= 18'd0;
                buzzer_out <= ~buzzer_out;
            end else begin
                buzzer_counter_reg <= buzzer_counter_reg + 1'b1;
            end
        end else begin
            buzzer_counter_reg <= 18'd0;
            buzzer_out <= 1'b0;
        end
    end
end

// --- Data Preparation for Modified Seven Segment Controller ---
// ******** CORRECTED: Changed wire to reg for procedural assignment ********
reg [2:0] display_base_note_id_internal;       // For 1-7 display on SEG1
reg [1:0] display_semitone_type_internal;    // 00: none, 01: sharp (#), 10: flat (b) for SEG0
reg       display_active_flag_internal;      // True if a valid note (not rest) is active for display
// *************************************************************************

always @(*) begin
    // Default assignments
    display_base_note_id_internal = 3'd0;
    display_semitone_type_internal = 2'b00;
    display_active_flag_internal = 1'b0;

    if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin
        display_active_flag_internal = 1'b1; // A valid note is active for display
        case (final_key_id_for_sound_and_display)
            // Natural notes
            4'd1:  begin display_base_note_id_internal = 3'd1; display_semitone_type_internal = 2'b00; end // C  (1)
            4'd2:  begin display_base_note_id_internal = 3'd2; display_semitone_type_internal = 2'b00; end // D  (2)
            4'd3:  begin display_base_note_id_internal = 3'd3; display_semitone_type_internal = 2'b00; end // E  (3)
            4'd4:  begin display_base_note_id_internal = 3'd4; display_semitone_type_internal = 2'b00; end // F  (4)
            4'd5:  begin display_base_note_id_internal = 3'd5; display_semitone_type_internal = 2'b00; end // G  (5)
            4'd6:  begin display_base_note_id_internal = 3'd6; display_semitone_type_internal = 2'b00; end // A  (6)
            4'd7:  begin display_base_note_id_internal = 3'd7; display_semitone_type_internal = 2'b00; end // B  (7)
            // Semitones as requested: KeyID -> Display Base Note + Suffix Type
            4'd8:  begin display_base_note_id_internal = 3'd1; display_semitone_type_internal = 2'b01; end // C# (ID 8) -> 1 # (H)
            4'd9:  begin display_base_note_id_internal = 3'd3; display_semitone_type_internal = 2'b10; end // Eb (ID 9) -> 3 b
            4'd10: begin display_base_note_id_internal = 3'd4; display_semitone_type_internal = 2'b01; end // F# (ID 10)-> 4 # (H)
            4'd11: begin display_base_note_id_internal = 3'd5; display_semitone_type_internal = 2'b01; end // G# (ID 11)-> 5 # (H)
            4'd12: begin display_base_note_id_internal = 3'd7; display_semitone_type_internal = 2'b10; end // Bb (ID 12)-> 7 b
            default: begin // Should not be hit for valid key_ids 1-12
                // Keep default assignments (blank, no suffix)
                // but mark display_active_flag_internal as false explicitly if needed
                display_active_flag_internal = 1'b0;
            end
        endcase
    end
    // If not pressed or is a rest (ID 0), defaults (blank, no suffix, inactive flag) from top of always block remain.
end

// --- Instantiate Seven Segment Controller (New Interface) ---
seven_segment_controller seven_segment_display_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .base_note_id_in(display_base_note_id_internal),      // For SEG1 (Note Digit)
    .semitone_type_in(display_semitone_type_internal),   // For SEG0 (Suffix #/b)
    .display_active_flag(display_active_flag_internal),  // Controls if SEG0/SEG1 show note data
    .octave_up_active(final_octave_up_for_sound_and_display),    // For SEG2 (Octave)
    .octave_down_active(final_octave_down_for_sound_and_display),// For SEG2 (Octave)

    .seg_a(seven_seg_a), .seg_b(seven_seg_b), .seg_c(seven_seg_c), .seg_d(seven_seg_d),
    .seg_e(seven_seg_e), .seg_f(seven_seg_f), .seg_g(seven_seg_g), .seg_dp(seven_seg_dp),
    .digit_selects(seven_seg_digit_selects)
);

// --- Optional LED Indicators ---
// assign led_is_recording = is_recording_status;
// assign led_is_playing_recording = is_playing_status && !is_song_playing_status;
// assign led_is_playing_song = is_song_playing_status;

endmodule