// File: fpga.v (Modified for practice mode integration)
// Top-level module for the FPGA Piano with recording, semitones, song playback, and practice mode

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
    output [7:0] seven_seg_digit_selects // For SEG0-SEG7
);

// --- Internal Reset Logic ---
wire rst_n_internal;
assign rst_n_internal = ~sw0_physical_reset;

// --- Debouncer Parameter ---
localparam DEBOUNCE_TIME_MS = 20;
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000);

// --- Consolidate All Musical Key Inputs ---
localparam NUM_BASE_KEYS = 7;
localparam NUM_SEMITONE_KEYS = 5;
localparam NUM_TOTAL_MUSICAL_KEYS = NUM_BASE_KEYS + NUM_SEMITONE_KEYS;
localparam RECORDER_KEY_ID_BITS = 4; // For 12 musical keys + rest (0)
localparam RECORDER_OCTAVE_BITS = 2;


wire [NUM_TOTAL_MUSICAL_KEYS-1:0] all_musical_keys_raw;
assign all_musical_keys_raw[0] = note_keys_physical_in[0]; // C -> ID 1 in scanner
assign all_musical_keys_raw[1] = note_keys_physical_in[1]; // D -> ID 2
assign all_musical_keys_raw[2] = note_keys_physical_in[2]; // E -> ID 3
assign all_musical_keys_raw[3] = note_keys_physical_in[3]; // F -> ID 4
assign all_musical_keys_raw[4] = note_keys_physical_in[4]; // G -> ID 5
assign all_musical_keys_raw[5] = note_keys_physical_in[5]; // A -> ID 6
assign all_musical_keys_raw[6] = note_keys_physical_in[6]; // B -> ID 7
assign all_musical_keys_raw[7] = key8_sharp1_raw;          // C# -> ID 8
assign all_musical_keys_raw[8] = key9_flat3_raw;           // Eb -> ID 9
assign all_musical_keys_raw[9] = key10_sharp4_raw;         // F# -> ID 10
assign all_musical_keys_raw[10] = key11_sharp5_raw;        // G# -> ID 11
assign all_musical_keys_raw[11] = key12_flat7_raw;         // Bb -> ID 12

// --- Keyboard Scanner Instance ---
wire [RECORDER_KEY_ID_BITS-1:0] current_active_key_id_internal; // Output from scanner (0 for none, 1-12 for keys)
wire       current_key_is_pressed_flag_internal;
keyboard_scanner #( .NUM_KEYS(NUM_TOTAL_MUSICAL_KEYS), .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS) )
keyboard_scanner_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .keys_in_raw(all_musical_keys_raw),
    .active_key_id(current_active_key_id_internal), .key_is_pressed(current_key_is_pressed_flag_internal)
);

// --- Debouncers for Control Keys ---
wire sw15_octave_up_debounced_internal, sw13_octave_down_debounced_internal;
wire sw16_record_debounced_internal, sw17_playback_debounced_internal, key14_play_song_debounced_internal;
wire sw17_playback_pulse_internal;

debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) octave_up_deb_inst (.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw15_octave_up_raw),   .key_out_debounced(sw15_octave_up_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) octave_down_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw13_octave_down_raw), .key_out_debounced(sw13_octave_down_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) record_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw16_record_raw),       .key_out_debounced(sw16_record_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) playback_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw17_playback_raw),     .key_out_debounced(sw17_playback_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) play_song_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(key14_play_song_raw),   .key_out_debounced(key14_play_song_debounced_internal));

reg sw17_playback_debounced_prev; initial sw17_playback_debounced_prev = 1'b0;
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) sw17_playback_debounced_prev <= 1'b0; else sw17_playback_debounced_prev <= sw17_playback_debounced_internal; end
assign sw17_playback_pulse_internal = sw17_playback_debounced_internal & ~sw17_playback_debounced_prev;

// --- Piano Recorder Instance ---
wire [RECORDER_KEY_ID_BITS-1:0] playback_key_id_feed; wire playback_key_is_pressed_feed;
wire playback_octave_up_feed, playback_octave_down_feed; wire is_recording_status, is_playing_status;
piano_recorder #( .CLK_FREQ_HZ(50_000_000), .RECORD_INTERVAL_MS(20), .MAX_RECORD_SAMPLES(512), .KEY_ID_BITS(RECORDER_KEY_ID_BITS), .OCTAVE_BITS(RECORDER_OCTAVE_BITS) )
piano_recorder_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .record_active_level(sw16_record_debounced_internal), .playback_start_pulse(sw17_playback_pulse_internal),
    .live_key_id(current_active_key_id_internal), .live_key_is_pressed(current_key_is_pressed_flag_internal),
    .live_octave_up(sw15_octave_up_debounced_internal), .live_octave_down(sw13_octave_down_debounced_internal),
    .playback_key_id(playback_key_id_feed), .playback_key_is_pressed(playback_key_is_pressed_feed),
    .playback_octave_up(playback_octave_up_feed), .playback_octave_down(playback_octave_down_feed),
    .is_recording(is_recording_status), .is_playing(is_playing_status)
);

// --- Song Player Instance ---
wire [RECORDER_KEY_ID_BITS-1:0] song_player_key_id_feed; wire song_player_key_is_pressed_feed;
wire song_player_octave_up_internal, song_player_octave_down_internal; wire is_song_playing_status;
song_player #( .CLK_FREQ_HZ(50_000_000), .KEY_ID_BITS(RECORDER_KEY_ID_BITS), .OCTAVE_BITS(RECORDER_OCTAVE_BITS) )
song_player_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .play_active_level(key14_play_song_debounced_internal),
    .song_key_id(song_player_key_id_feed), .song_key_is_pressed(song_player_key_is_pressed_feed),
    .song_octave_up_feed(song_player_octave_up_internal), .song_octave_down_feed(song_player_octave_down_internal),
    .is_song_playing(is_song_playing_status)
);

// --- Mode Sequencer Instance (NEW) ---
wire practice_mode_trigger_pulse_internal;
mode_sequencer mode_sequencer_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .current_live_key_id(current_active_key_id_internal), // From keyboard_scanner
    .current_live_key_pressed(current_key_is_pressed_flag_internal), // From keyboard_scanner
    .practice_mode_active_pulse(practice_mode_trigger_pulse_internal)
);

// --- Practice Mode Enable Logic (NEW) ---
reg practice_mode_enabled_reg; initial practice_mode_enabled_reg = 1'b0;
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if (!rst_n_internal) begin
        practice_mode_enabled_reg <= 1'b0;
    end else begin
        if (practice_mode_trigger_pulse_internal) begin
            practice_mode_enabled_reg <= ~practice_mode_enabled_reg; // Toggle practice mode
        end
    end
end

// --- Practice Player Instance (NEW) ---
localparam NUM_PRACTICE_DISPLAY_SEGMENTS = 6;
wire [2:0] practice_data_s0; // For display_out_seg0 from practice_player
wire [2:0] practice_data_s1;
wire [2:0] practice_data_s2;
wire [2:0] practice_data_s3;
wire [2:0] practice_data_s4;
wire [2:0] practice_data_s5;// Array for practice display data
wire practice_correct_event;
wire practice_wrong_event;
wire practice_finished_event;

// In fpga.v, practice_player_inst instantiation
practice_player #( .NUM_DISPLAY_SEGMENTS(NUM_PRACTICE_DISPLAY_SEGMENTS) ) practice_player_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .practice_mode_active(practice_mode_enabled_reg),
    .current_live_key_id(current_active_key_id_internal),
    .current_live_key_pressed(current_key_is_pressed_flag_internal),
    //.display_data_practice_seg(practice_seg_data_feed), // OLD
    // NEW: Connect to individual ports
    .display_out_seg0(practice_data_s0),
    .display_out_seg1(practice_data_s1),
    .display_out_seg2(practice_data_s2),
    .display_out_seg3(practice_data_s3),
    .display_out_seg4(practice_data_s4),
    .display_out_seg5(practice_data_s5),
    .correct_note_played_event(practice_correct_event),
    .wrong_note_played_event(practice_wrong_event),
    .practice_song_finished_event(practice_finished_event)
);
// --- Sound/Display Source Multiplexer (MODIFIED for practice mode) ---
wire [RECORDER_KEY_ID_BITS-1:0] final_key_id_for_sound_and_display;
wire final_key_is_pressed_for_sound_and_display;
wire final_octave_up_for_sound_and_display, final_octave_down_for_sound_and_display;

// In practice mode, sound/display logic will be different.
// For now, let's assume practice mode itself doesn't directly drive the main buzzer/display for notes
// (it has its own display feed: practice_seg_data_feed, and event flags for sound).
// So, if practice_mode is on, the main sound generation from keys might be disabled or handled differently.

// Priority: Song Player > Recorded Playback > Live Keys (IF NOT IN PRACTICE MODE or if practice allows live passthrough)
// In fpga.v
// --- Sound/Display Source Multiplexer (MODIFIED for practice mode sound) ---
// ... (final_key_id_for_sound_and_display etc. declarations) ...

// Priority:
// 1. Practice Mode: Sound from live keys
// 2. Song Player
// 3. Recorded Playback
// 4. Live Keys (normal mode)

assign final_key_id_for_sound_and_display =
    (practice_mode_enabled_reg) ? current_active_key_id_internal : // <<< CHANGE: Sound from live keys in practice
    (is_song_playing_status ? song_player_key_id_feed :
    (is_playing_status ? playback_key_id_feed : current_active_key_id_internal));

assign final_key_is_pressed_for_sound_and_display =
    (practice_mode_enabled_reg) ? current_key_is_pressed_flag_internal : // <<< CHANGE: Use live key press flag
    (is_song_playing_status ? song_player_key_is_pressed_feed :
    (is_playing_status ? playback_key_is_pressed_feed : current_key_is_pressed_flag_internal));

// Octave for practice mode sound will also come from global octave buttons with this change
assign final_octave_up_for_sound_and_display =
    (is_song_playing_status && !practice_mode_enabled_reg) ? song_player_octave_up_internal : // Song octave only if not in practice
    ((is_playing_status && !practice_mode_enabled_reg) ? playback_octave_up_feed : // Playback octave only if not in practice
    sw15_octave_up_debounced_internal); // Live/Practice octave

assign final_octave_down_for_sound_and_display =
    (is_song_playing_status && !practice_mode_enabled_reg) ? song_player_octave_down_internal :
    ((is_playing_status && !practice_mode_enabled_reg) ? playback_octave_down_feed :
    sw13_octave_down_debounced_internal);

// --- Buzzer Frequency Generation ---
localparam CNT_C4=17'd95566, CNT_CS4=17'd90194, CNT_D4=17'd85135, CNT_DS4=17'd80346, CNT_E4=17'd75830;
localparam CNT_F4=17'd71569, CNT_FS4=17'd67569, CNT_G4=17'd63775, CNT_GS4=17'd60197, CNT_A4=17'd56817;
localparam CNT_AS4=17'd53627,CNT_B4=17'd50619;

reg [17:0] buzzer_counter_reg;
reg [17:0] base_note_target_count;
reg [17:0] final_target_count_max;

// Combinational logic for sound generation
always @(*) begin
    case (final_key_id_for_sound_and_display) // This uses the muxed output
        4'd1:  base_note_target_count = CNT_C4;  4'd8:  base_note_target_count = CNT_CS4;
        4'd2:  base_note_target_count = CNT_D4;  4'd9:  base_note_target_count = CNT_DS4;
        4'd3:  base_note_target_count = CNT_E4;  // No default Eb (ID 9 used by you)
        4'd4:  base_note_target_count = CNT_F4;  4'd10: base_note_target_count = CNT_FS4;
        4'd5:  base_note_target_count = CNT_G4;  4'd11: base_note_target_count = CNT_GS4;
        4'd6:  base_note_target_count = CNT_A4;  4'd12: base_note_target_count = CNT_AS4;
        4'd7:  base_note_target_count = CNT_B4;
        default: base_note_target_count = 18'h3FFFF; // Silent
    endcase

    if (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display) begin
        final_target_count_max = (base_note_target_count + 1) / 2 - 1;
    end else if (!final_octave_up_for_sound_and_display && final_octave_down_for_sound_and_display) begin
        final_target_count_max = (base_note_target_count + 1) * 2 - 1;
    end else begin
        final_target_count_max = base_note_target_count;
    end
end

initial begin buzzer_out = 1'b0; buzzer_counter_reg = 18'd0; end

always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) begin
        buzzer_counter_reg <= 18'd0; buzzer_out <= 1'b0;
    // MODIFIED: Buzzer logic needs to consider practice mode feedback sounds
    // This is a SIMPLIFICATION. A more complex sound muxer might be needed.
    // For now, main buzzer responds to final_key_is_pressed...
    // Practice mode correct/wrong events could trigger specific short tones via another PWM or by briefly overriding these.
    end else if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin
        if (buzzer_counter_reg >= final_target_count_max) begin
            buzzer_counter_reg <= 18'd0; buzzer_out <= ~buzzer_out;
        end else begin
            buzzer_counter_reg <= buzzer_counter_reg + 1'b1;
        end
    // NEW: Add simple feedback for practice mode (can be improved)
    end else if (practice_correct_event) begin // Brief high tone for correct
        // This is a placeholder for a proper sound. It will conflict if a note is also sounding.
        // A dedicated sound generator for feedback is better.
        // For now, let's make it a very short click or high pitch.
        // This simple version might not sound good.
        buzzer_counter_reg <= 18'd0; // This will make it ~440Hz if CNT_A4 is target
        //buzzer_out <= ~buzzer_out; // Pulsing might be too short
    end else if (practice_wrong_event) begin // Brief low tone for wrong
        //buzzer_counter_reg <= CNT_C4 * 2; // Example very low freq
        //buzzer_out <= ~buzzer_out;
    end else begin
        buzzer_counter_reg <= 18'd0; buzzer_out <= 1'b0; // No key, no feedback
    end
end


// --- Data Preparation for Display Modules (MODIFIED for practice mode priority on SEG0/SEG7) ---
reg [2:0] base_note_id_for_buffer_and_suffix;
reg [1:0] semitone_type_for_suffix;
reg       current_note_is_valid_for_display;

// This always block prepares data primarily for the scrolling display (non-practice)
// and for the semitone suffix on SEG0.
always @(*) begin
    base_note_id_for_buffer_and_suffix = 3'd0;
    semitone_type_for_suffix = 2'b00;
    current_note_is_valid_for_display = 1'b0;

    // If in practice mode, SEG0/SEG7 might show different things (handled in seven_segment_controller)
    // This section is for when NOT in practice mode, or for the general note pressed
    if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin
        current_note_is_valid_for_display = 1'b1;
        case (final_key_id_for_sound_and_display)
            4'd1:  begin base_note_id_for_buffer_and_suffix = 3'd1; semitone_type_for_suffix = 2'b00; end // C
            4'd2:  begin base_note_id_for_buffer_and_suffix = 3'd2; semitone_type_for_suffix = 2'b00; end // D
            4'd3:  begin base_note_id_for_buffer_and_suffix = 3'd3; semitone_type_for_suffix = 2'b00; end // E
            4'd4:  begin base_note_id_for_buffer_and_suffix = 3'd4; semitone_type_for_suffix = 2'b00; end // F
            4'd5:  begin base_note_id_for_buffer_and_suffix = 3'd5; semitone_type_for_suffix = 2'b00; end // G
            4'd6:  begin base_note_id_for_buffer_and_suffix = 3'd6; semitone_type_for_suffix = 2'b00; end // A
            4'd7:  begin base_note_id_for_buffer_and_suffix = 3'd7; semitone_type_for_suffix = 2'b00; end // B
            4'd8:  begin base_note_id_for_buffer_and_suffix = 3'd1; semitone_type_for_suffix = 2'b01; end // C#
            4'd9:  begin base_note_id_for_buffer_and_suffix = 3'd3; semitone_type_for_suffix = 2'b10; end // Eb
            4'd10: begin base_note_id_for_buffer_and_suffix = 3'd4; semitone_type_for_suffix = 2'b01; end // F#
            4'd11: begin base_note_id_for_buffer_and_suffix = 3'd5; semitone_type_for_suffix = 2'b01; end // G#
            4'd12: begin base_note_id_for_buffer_and_suffix = 3'd7; semitone_type_for_suffix = 2'b10; end // Bb
            default: current_note_is_valid_for_display = 1'b0;
        endcase
    end
end

// --- Generate Pulse for New Valid Note to Trigger Scrolling Buffer ---
reg  final_key_is_pressed_for_sound_and_display_prev;
reg  [RECORDER_KEY_ID_BITS-1:0] final_key_id_for_sound_and_display_prev;
wire new_note_to_scroll_pulse;

initial begin
    final_key_is_pressed_for_sound_and_display_prev = 1'b0;
    final_key_id_for_sound_and_display_prev = {RECORDER_KEY_ID_BITS{1'b0}};
end

always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) begin
        final_key_is_pressed_for_sound_and_display_prev <= 1'b0;
        final_key_id_for_sound_and_display_prev <= {RECORDER_KEY_ID_BITS{1'b0}};
    end else begin
        final_key_is_pressed_for_sound_and_display_prev <= final_key_is_pressed_for_sound_and_display;
        if (final_key_is_pressed_for_sound_and_display) begin
            final_key_id_for_sound_and_display_prev <= final_key_id_for_sound_and_display;
        end else begin
            final_key_id_for_sound_and_display_prev <= {RECORDER_KEY_ID_BITS{1'b0}};
        end
    end
end

assign new_note_to_scroll_pulse =
    !practice_mode_enabled_reg && // Only scroll if NOT in practice mode
    (
        (final_key_is_pressed_for_sound_and_display && !final_key_is_pressed_for_sound_and_display_prev) ||
        (final_key_is_pressed_for_sound_and_display && (final_key_id_for_sound_and_display != final_key_id_for_sound_and_display_prev))
    ) && current_note_is_valid_for_display;

// --- Instantiate Scrolling Display Buffer ---
wire [2:0] scroll_data_seg1_feed; wire [2:0] scroll_data_seg2_feed;
wire [2:0] scroll_data_seg3_feed; wire [2:0] scroll_data_seg4_feed;
wire [2:0] scroll_data_seg5_feed; wire [2:0] scroll_data_seg6_feed;

scrolling_display_buffer scroller_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .new_note_valid_pulse(new_note_to_scroll_pulse),
    .current_base_note_id_in(base_note_id_for_buffer_and_suffix),
    .display_data_seg1(scroll_data_seg1_feed),
    .display_data_seg2(scroll_data_seg2_feed),
    .display_data_seg3(scroll_data_seg3_feed),
    .display_data_seg4(scroll_data_seg4_feed),
    .display_data_seg5(scroll_data_seg5_feed),
    .display_data_seg6(scroll_data_seg6_feed)
);

// --- Wires for final data to seven_segment_controller (NEW) ---
wire [2:0] final_to_sev_seg1_data; wire [2:0] final_to_sev_seg2_data;
wire [2:0] final_to_sev_seg3_data; wire [2:0] final_to_sev_seg4_data;
wire [2:0] final_to_sev_seg5_data; wire [2:0] final_to_sev_seg6_data;

// --- Multiplex data for SEG1-SEG6 display (NEW) ---
assign final_to_sev_seg1_data = practice_mode_enabled_reg ? practice_data_s0 : scroll_data_seg1_feed;
assign final_to_sev_seg2_data = practice_mode_enabled_reg ? practice_data_s1 : scroll_data_seg2_feed;
assign final_to_sev_seg3_data = practice_mode_enabled_reg ? practice_data_s2 : scroll_data_seg3_feed;
assign final_to_sev_seg4_data = practice_mode_enabled_reg ? practice_data_s3 : scroll_data_seg4_feed;
assign final_to_sev_seg5_data = practice_mode_enabled_reg ? practice_data_s4 : scroll_data_seg5_feed;
assign final_to_sev_seg6_data = practice_mode_enabled_reg ? practice_data_s5 : scroll_data_seg6_feed;
// --- Instantiate Seven Segment Controller (MODIFIED inputs) ---
seven_segment_controller seven_segment_display_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),

    // Inputs for SEG0 (Suffix / Practice Mode Indicator)
    // MODIFIED: If in practice, show 'P', else show semitone.
    .semitone_type_in(practice_mode_enabled_reg ? 2'b11 : semitone_type_for_suffix), // 2'b11 can be a code for 'P' in your controller
    .semitone_display_active_flag(practice_mode_enabled_reg ? 1'b1 : current_note_is_valid_for_display),

    // Inputs for SEG1-SEG6 (Muxed data)
    .scrolled_note_seg1_in(final_to_sev_seg1_data),
    .scrolled_note_seg2_in(final_to_sev_seg2_data),
    .scrolled_note_seg3_in(final_to_sev_seg3_data),
    .scrolled_note_seg4_in(final_to_sev_seg4_data),
    .scrolled_note_seg5_in(final_to_sev_seg5_data),
    .scrolled_note_seg6_in(final_to_sev_seg6_data),

    // Inputs for SEG7 (Octave / Practice Feedback)
    // MODIFIED: If in practice, show feedback (e.g., based on practice_correct_event), else octave.
    .octave_up_active(practice_mode_enabled_reg ? practice_correct_event : (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display)),
    .octave_down_active(practice_mode_enabled_reg ? practice_wrong_event : (final_octave_down_for_sound_and_display && !final_octave_up_for_sound_and_display)),

    // Seven Segment Outputs
    .seg_a(seven_seg_a), .seg_b(seven_seg_b), .seg_c(seven_seg_c), .seg_d(seven_seg_d),
    .seg_e(seven_seg_e), .seg_f(seven_seg_f), .seg_g(seven_seg_g), .seg_dp(seven_seg_dp),
    .digit_selects(seven_seg_digit_selects)
);

endmodule