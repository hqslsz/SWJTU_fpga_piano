# fpga
SWJTU数电课设电子琴

## 核心代码
### 1.顶层fpga.v
```verilog
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
```
### debouncer.v
```verilog
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
```
### keyboard_scanner.v
```verilog
// File: keyboard_scanner.v
// Scans multiple keys, debounces them, and outputs the ID of the highest priority pressed key.

module keyboard_scanner #(
    parameter NUM_KEYS = 7, // Default value, will be overridden by the top module (e.g., to 12)
    parameter DEBOUNCE_TIME_MS = 20
) (
    input clk,
    input rst_n,                          // Active low reset
    input [NUM_KEYS-1:0] keys_in_raw,   // Raw inputs from keys (e.g., keys_in_raw[0] for Key1)

    // Output ID can be 0 (no key) or 1 up to NUM_KEYS.
    // So, it needs to represent NUM_KEYS + 1 distinct values.
    // The width required is $clog2(NUM_KEYS + 1).
    // Example: NUM_KEYS = 7 -> $clog2(8) = 3 bits (for 0-7)
    // Example: NUM_KEYS = 12 -> $clog2(13) = 4 bits (for 0-12)
    output reg [$clog2(NUM_KEYS + 1) - 1 : 0] active_key_id,
    output reg key_is_pressed           // High if any key is currently pressed (debounced)
);

// Calculate debounce cycles based on 50MHz clock (passed via DEBOUNCE_TIME_MS)
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000); // Assuming 50MHz clock

// Array of debounced key states
wire [NUM_KEYS-1:0] keys_debounced_signals;

// Instantiate debouncers for each key
genvar i;
generate
    for (i = 0; i < NUM_KEYS; i = i + 1) begin : debounce_gen_block
        debouncer #(
            .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC)
        ) inst_debouncer (
            .clk(clk),
            .rst_n(rst_n),
            .key_in_raw(keys_in_raw[i]),
            .key_out_debounced(keys_debounced_signals[i])
        );
    end
endgenerate

// Declare loop variable for Verilog-2001 compatibility if needed by older tools
// For modern tools, 'j' can be declared directly in the for loop if 'automatic' is not desired for synthesis.
integer j;

// Logic to determine active_key_id and key_is_pressed
// Priority: If multiple keys are pressed, lowest index key (keys_in_raw[0]) wins.
always @(*) begin
    key_is_pressed = 1'b0;      // Initialize: assume no key is pressed yet
    // Initialize active_key_id to 0 (no key pressed). Ensure correct width.
    active_key_id = {$clog2(NUM_KEYS + 1){1'b0}};

    // Iterate from lowest index (Key1, which is keys_debounced_signals[0])
    // to highest. The first one found will set the outputs.
    for (j = 0; j < NUM_KEYS; j = j + 1) begin
        if (keys_debounced_signals[j]) begin // If this key 'j' is pressed
            if (!key_is_pressed) begin       // AND if we haven't already found a lower-index pressed key
                key_is_pressed = 1'b1;
                active_key_id = j + 1;     // Assign its ID (j=0 is ID 1, j=1 is ID 2, etc.)
            end
        end
    end
end

endmodule
```
### seven_segment_controller.v
```verilog
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
```
### piano_recorder.v
```verilog
// File: piano_recorder.v
// Module for recording and playing back piano key presses.

module piano_recorder #(
    parameter CLK_FREQ_HZ      = 50_000_000, // System clock frequency
    parameter RECORD_INTERVAL_MS = 20,       // Interval for sampling/playback (e.g., 20ms)
    parameter MAX_RECORD_SAMPLES = 512,    // Max number of samples to record
    parameter KEY_ID_BITS      = 3,        // Bits for key ID (0 for none, 1-N for keys) - Default, will be overridden
    parameter OCTAVE_BITS      = 2         // Bits for octave state (00:normal, 01:up, 10:down)
) (
    input clk,
    input rst_n, // Active low reset

    // Control signals (expected to be debounced externally)
    input record_active_level,     // High when record button (e.g., SW16) is held down
    input playback_start_pulse,    // A single clock cycle pulse to start playback (e.g., on SW17 press)

    // Inputs from main piano logic (live playing)
    input [KEY_ID_BITS-1:0] live_key_id,       // Current key ID being pressed (0 if none)
    input live_key_is_pressed,                 // Flag: is a live key currently pressed?
    input live_octave_up,                      // Flag: is live octave up active?
    input live_octave_down,                    // Flag: is live octave down active?

    // Outputs to drive buzzer and display during playback
    output reg [KEY_ID_BITS-1:0] playback_key_id,
    output reg playback_key_is_pressed,
    output wire playback_octave_up,   // Changed from reg to wire
    output wire playback_octave_down, // Changed from reg to wire

    // Status outputs (optional, for LEDs or debugging)
    output reg is_recording,
    output reg is_playing
);

// --- Derived Parameters ---
localparam RECORD_INTERVAL_CYCLES = (RECORD_INTERVAL_MS * (CLK_FREQ_HZ / 1000)); // Cycles per interval
localparam ADDR_WIDTH = $clog2(MAX_RECORD_SAMPLES); // Width for memory address
// Data format per sample: {octave_state[1:0], key_is_pressed (1), key_id[KEY_ID_BITS-1:0]}
localparam DATA_WIDTH = OCTAVE_BITS + 1 + KEY_ID_BITS;

// --- Memory for Recording ---
// Quartus will infer this as RAM (M9K blocks if available and appropriate size)
reg [DATA_WIDTH-1:0] recorded_data_memory [0:MAX_RECORD_SAMPLES-1];
reg [ADDR_WIDTH-1:0] record_write_ptr;    // Points to the next empty slot for recording
reg [ADDR_WIDTH-1:0] playback_read_ptr;   // Points to the current sample to play
reg [ADDR_WIDTH-1:0] last_recorded_ptr;   // Stores the address of the last valid recorded sample + 1 (i.e., length)

// --- Timers and Counters ---
reg [$clog2(RECORD_INTERVAL_CYCLES)-1:0] sample_timer_reg;

// --- State Machine ---
localparam S_IDLE      = 2'b00;
localparam S_RECORDING = 2'b01;
localparam S_PLAYBACK  = 2'b10;
reg [1:0] current_state_reg;

// --- Internal signals for octave encoding/decoding ---
wire [OCTAVE_BITS-1:0] live_octave_encoded;
assign live_octave_encoded = (live_octave_up && !live_octave_down) ? 2'b01 :      // Up
                             (!live_octave_up && live_octave_down) ? 2'b10 :      // Down
                             2'b00;                                              // Normal (or both pressed)

reg [OCTAVE_BITS-1:0] playback_octave_encoded; // Changed from wire to reg
assign playback_octave_up   = (playback_octave_encoded == 2'b01);
assign playback_octave_down = (playback_octave_encoded == 2'b10);


initial begin
    is_recording = 1'b0;
    is_playing = 1'b0;
    playback_key_id = {KEY_ID_BITS{1'b0}}; // Ensure correct width for 0
    playback_key_is_pressed = 1'b0;
    playback_octave_encoded = {OCTAVE_BITS{1'b0}}; // Initialize to normal
    current_state_reg = S_IDLE;
    record_write_ptr = {ADDR_WIDTH{1'b0}};
    playback_read_ptr = {ADDR_WIDTH{1'b0}};
    last_recorded_ptr = {ADDR_WIDTH{1'b0}};
    sample_timer_reg = 0; // Assuming its width is sufficient for 0
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        is_recording <= 1'b0;
        is_playing <= 1'b0;
        playback_key_id <= {KEY_ID_BITS{1'b0}};
        playback_key_is_pressed <= 1'b0;
        playback_octave_encoded <= {OCTAVE_BITS{1'b0}}; // Reset to normal
        current_state_reg <= S_IDLE;
        record_write_ptr <= {ADDR_WIDTH{1'b0}};
        playback_read_ptr <= {ADDR_WIDTH{1'b0}};
        last_recorded_ptr <= {ADDR_WIDTH{1'b0}};
        sample_timer_reg <= 0;
    end else begin
        // Default actions, can be overridden by states
        if (current_state_reg != S_PLAYBACK) begin // Only reset playback outputs if not actively playing
             playback_key_is_pressed <= 1'b0;
             playback_key_id <= {KEY_ID_BITS{1'b0}};
             playback_octave_encoded <= {OCTAVE_BITS{1'b0}};
        end
        if (current_state_reg != S_RECORDING) begin
            is_recording <= 1'b0;
        end
        if (current_state_reg != S_PLAYBACK) begin
            is_playing <= 1'b0;
        end


        case (current_state_reg)
            S_IDLE: begin
                sample_timer_reg <= 0; // Reset timer in IDLE

                if (record_active_level) begin // SW16 pressed to start recording
                    current_state_reg <= S_RECORDING;
                    record_write_ptr <= {ADDR_WIDTH{1'b0}}; // Start recording from the beginning
                    is_recording <= 1'b1;
                    last_recorded_ptr <= {ADDR_WIDTH{1'b0}}; // Reset length of current recording
                end else if (playback_start_pulse && last_recorded_ptr > 0) begin // SW17 pressed and there's something to play
                    current_state_reg <= S_PLAYBACK;
                    playback_read_ptr <= {ADDR_WIDTH{1'b0}}; // Start playback from the beginning
                    is_playing <= 1'b1;
                    sample_timer_reg <= RECORD_INTERVAL_CYCLES -1; // Preload to play first sample immediately
                end
            end

            S_RECORDING: begin
                is_recording <= 1'b1; // Keep is_recording high
                if (!record_active_level || record_write_ptr >= MAX_RECORD_SAMPLES) begin // SW16 released or memory full
                    current_state_reg <= S_IDLE;
                    // is_recording will be set to 0 by default action or IDLE entry
                    last_recorded_ptr <= record_write_ptr; // Save how much we recorded (number of samples)
                end else begin
                    if (sample_timer_reg == RECORD_INTERVAL_CYCLES - 1) begin
                        sample_timer_reg <= 0;
                        // Store: {octave_state[1:0], live_key_is_pressed, live_key_id[KEY_ID_BITS-1:0]}
                        recorded_data_memory[record_write_ptr] <= {live_octave_encoded, live_key_is_pressed, live_key_id};
                        
                        if (record_write_ptr < MAX_RECORD_SAMPLES - 1 ) begin
                           record_write_ptr <= record_write_ptr + 1;
                        end else begin // Memory is now full (last slot used)
                           current_state_reg <= S_IDLE;
                           last_recorded_ptr <= MAX_RECORD_SAMPLES; // Record that memory is full
                        end
                    end else begin
                        sample_timer_reg <= sample_timer_reg + 1;
                    end
                end
            end

            S_PLAYBACK: begin
                is_playing <= 1'b1; // Keep is_playing high
                // Check if playback should stop
                if (playback_read_ptr >= last_recorded_ptr || playback_read_ptr >= MAX_RECORD_SAMPLES ) begin
                    current_state_reg <= S_IDLE;
                    // is_playing and playback outputs will be reset by default action or IDLE entry
                end else begin
                    if (sample_timer_reg == RECORD_INTERVAL_CYCLES - 1) begin
                        sample_timer_reg <= 0;
                        // Read data: {octave_state, key_pressed, key_id}
                        {playback_octave_encoded, playback_key_is_pressed, playback_key_id} <= recorded_data_memory[playback_read_ptr];
                        
                        if (playback_read_ptr < MAX_RECORD_SAMPLES - 1 && playback_read_ptr < last_recorded_ptr -1 ) begin
                            playback_read_ptr <= playback_read_ptr + 1;
                        end else begin // Reached end of data to play or last valid sample
                            current_state_reg <= S_IDLE;
                        end
                    end else begin
                        sample_timer_reg <= sample_timer_reg + 1;
                    end
                end
            end
            default: current_state_reg <= S_IDLE;
        endcase
    end
end
endmodule
```
### song_player.v
```verilog
// File: song_player.v
module song_player #(
    parameter CLK_FREQ_HZ = 50_000_000,
    parameter KEY_ID_BITS = 4,         // For C, C#, D ... B (12 notes + REST)
    parameter OCTAVE_BITS = 2          // To represent Low, Middle, High octaves
) (
    input clk,
    input rst_n,
    input play_active_level,          // 高电平播放，低电平停止

    output reg [KEY_ID_BITS-1:0] song_key_id,
    output reg song_key_is_pressed,
    output reg song_octave_up_feed,    // New output for octave up
    output reg song_octave_down_feed,  // New output for octave down
    output reg is_song_playing        // 歌曲正在播放的状态指示
);

    // --- 音符定义 (KEY_ID 1-12) ---
    localparam NOTE_C   = 4'd1; localparam NOTE_CS  = 4'd8;  // C, C#
    localparam NOTE_D   = 4'd2; localparam NOTE_DS  = 4'd9;  // D, D# (Eb)
    localparam NOTE_E   = 4'd3;                             // E
    localparam NOTE_F   = 4'd4; localparam NOTE_FS  = 4'd10; // F, F#
    localparam NOTE_G   = 4'd5; localparam NOTE_GS  = 4'd11; // G, G# (Ab)
    localparam NOTE_A   = 4'd6; localparam NOTE_AS  = 4'd12; // A, A# (Bb)
    localparam NOTE_B   = 4'd7;                             // B
    localparam REST     = 4'd0; // 休止符

    // --- 八度定义 ---
    localparam OCTAVE_LOW  = 2'b10; // Signal to activate octave_down
    localparam OCTAVE_MID  = 2'b00; // Signal for normal (middle) octave
    localparam OCTAVE_HIGH = 2'b01; // Signal to activate octave_up

    // --- 时长和乐谱数据定义 ---
    localparam DURATION_BITS = 4;     // 用于表示时长单位的位数
    localparam SONG_DATA_WIDTH = OCTAVE_BITS + KEY_ID_BITS + DURATION_BITS;

    // !!! REPLACE THIS WITH THE CORRECT SONG_LENGTH FROM YOUR MIDI CONVERSION !!!
    localparam SONG_LENGTH = 232; // EXAMPLE - Use the actual length from your transcription

    // --- 节拍和基础时长单位 ---
    // !!! ENSURE THIS MATCHES THE VALUE USED FOR YOUR MIDI TRANSCRIPTION !!!
    localparam BASIC_NOTE_DURATION_MS = 70;
    localparam BASIC_NOTE_DURATION_CYCLES = (BASIC_NOTE_DURATION_MS * (CLK_FREQ_HZ / 1000));
    localparam MAX_DURATION_UNITS_VAL = (1 << DURATION_BITS) - 1;

    // --- 状态机定义 ---
    localparam S_IDLE   = 1'b0;
    localparam S_PLAYING= 1'b1;

    // --- 内部寄存器声明 ---
    reg [SONG_DATA_WIDTH-1:0] song_rom [0:SONG_LENGTH-1];

    reg [$clog2(SONG_LENGTH)-1:0] current_note_index;
    reg [$clog2(BASIC_NOTE_DURATION_CYCLES * MAX_DURATION_UNITS_VAL + 1)-1:0] note_duration_timer;
    reg [DURATION_BITS-1:0] current_note_duration_units;
    reg [KEY_ID_BITS-1:0] current_note_id_from_rom;
    reg [OCTAVE_BITS-1:0] current_octave_code_from_rom;
    reg state;
    reg play_active_level_prev;


    // ########################################################################## //
    // #                                                                        # //
    // #    <<<<< REPLACE THE ENTIRE 'initial begin ... end' BLOCK BELOW >>>>>  # //
    // #    <<<<< WITH THE ONE CONTAINING YOUR TRANSCRIBED song_rom DATA >>>>>  # //
    // #                                                                        # //
    // ########################################################################## //
    initial begin
        // THIS IS A PLACEHOLDER - REPLACE IT WITH YOUR ACTUAL SONG_ROM INITIALIZATION
        // Example:
        // song_rom[0]  = {OCTAVE_LOW,  NOTE_D,   4'd2};
        // song_rom[1]  = {OCTAVE_MID,  REST,     4'd2};
        // ... many more lines ...
        // song_rom[SONG_LENGTH-1] = {OCTAVE_MID, REST, 4'd4}; // Last note or rest

        // Ensure all song_rom entries are initialized, especially if your
        // transcription doesn't fill the entire SONG_LENGTH.
        integer i;
        for (i = 0; i < SONG_LENGTH; i = i + 1) begin
            // If you provide all entries explicitly, this loop can be minimal or removed
            // If your transcription is shorter than SONG_LENGTH, fill the rest:
            if (i >= 232) begin // Assuming your transcription has 232 entries (0 to 231)
                 song_rom[i] = {OCTAVE_MID, REST, 4'd1}; // Default fill
            end
            // If your transcription has fewer entries than the example (232), adjust the 'if' condition.
            // Or, just ensure your transcription defines ALL song_rom[0] through song_rom[SONG_LENGTH-1].
        end
        // Make sure song_rom[0] to song_rom[231] (or however many entries you have) are defined
        // by the MIDI transcription part. For example:
        song_rom[0]  = {OCTAVE_LOW,  NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1429s
        song_rom[1]  = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1413s
        song_rom[2]  = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        // ... (The 232 lines of song_rom data you generated previously) ...
        song_rom[231] = {OCTAVE_LOW, NOTE_FS,  4'd8}; // MIDI 54 (F#3), Dur: 0.5715s

        // Initialize outputs and internal state registers (This part should be AT THE END of your initial block)
        song_key_id = {KEY_ID_BITS{1'b0}};
        song_key_is_pressed = 1'b0;
        song_octave_up_feed = 1'b0;
        song_octave_down_feed = 1'b0;
        is_song_playing = 1'b0;
        state = S_IDLE;
        current_note_index = 0;
        note_duration_timer = 0;
        current_note_duration_units = 0;
        current_note_id_from_rom = {KEY_ID_BITS{1'b0}};
        current_octave_code_from_rom = OCTAVE_MID;
        play_active_level_prev = 1'b0;
    end
    // ################# END OF BLOCK TO BE REPLACED ######################## //


    // --- 主要状态机和逻辑 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位状态
            song_key_id <= {KEY_ID_BITS{1'b0}};
            song_key_is_pressed <= 1'b0;
            song_octave_up_feed <= 1'b0;
            song_octave_down_feed <= 1'b0;
            is_song_playing <= 1'b0;
            state <= S_IDLE;
            current_note_index <= 0;
            note_duration_timer <= 0;
            current_note_duration_units <= 0;
            current_note_id_from_rom <= {KEY_ID_BITS{1'b0}};
            current_octave_code_from_rom <= OCTAVE_MID;
            play_active_level_prev <= 1'b0;
        end else begin
            play_active_level_prev <= play_active_level; // 存储当前按键电平，用于下一周期检测边沿

            // 首要停止条件: 如果播放按键变为低电平且当前正在播放，则立即停止
            if (!play_active_level && state == S_PLAYING) begin
                state <= S_IDLE;
                song_key_is_pressed <= 1'b0; // 静音
                song_octave_up_feed <= 1'b0;   // Reset on stop
                song_octave_down_feed <= 1'b0; // Reset on stop
                is_song_playing <= 1'b0;   // 更新状态
            end

            // 状态机逻辑
            case (state)
                S_IDLE: begin
                    song_key_is_pressed <= 1'b0; // 在IDLE状态确保静音
                    song_octave_up_feed <= 1'b0;
                    song_octave_down_feed <= 1'b0;
                    is_song_playing <= 1'b0;   // 在IDLE状态确保播放状态为否

                    // 如果播放按键按下 (检测上升沿)
                    if (play_active_level && !play_active_level_prev) begin
                        if (SONG_LENGTH > 0) begin // Only play if there's a song
                            state <= S_PLAYING;     // 进入播放状态
                            current_note_index <= 0;  // 从乐谱开头播放
                            // 读取第一个音符
                            {current_octave_code_from_rom, current_note_id_from_rom, current_note_duration_units} = song_rom[0];

                            song_key_id <= current_note_id_from_rom;
                            song_key_is_pressed <= (current_note_id_from_rom != REST);
                            song_octave_up_feed <= (current_octave_code_from_rom == OCTAVE_HIGH);
                            song_octave_down_feed <= (current_octave_code_from_rom == OCTAVE_LOW);

                            note_duration_timer <= 0; // 重置音符时长计时器
                            is_song_playing <= 1'b1;  // 设置播放状态为是
                        end
                    end
                end // S_IDLE 结束

                S_PLAYING: begin
                    // 只有当播放按键仍然按下时才继续处理播放逻辑
                    if (play_active_level) begin
                        is_song_playing <= 1'b1; // 保持播放状态为是

                        if (current_note_duration_units == 0) begin // If current note has 0 duration (should ideally not happen from good ROM)
                            // Defensive: skip to next note or stop if at end
                            if (current_note_index < SONG_LENGTH - 1) begin
                                current_note_index <= current_note_index + 1;
                                {current_octave_code_from_rom, current_note_id_from_rom, current_note_duration_units} = song_rom[current_note_index + 1];
                                song_key_id <= current_note_id_from_rom;
                                song_key_is_pressed <= (current_note_id_from_rom != REST);
                                song_octave_up_feed <= (current_octave_code_from_rom == OCTAVE_HIGH);
                                song_octave_down_feed <= (current_octave_code_from_rom == OCTAVE_LOW);
                                note_duration_timer <= 0;
                            end else begin // 已经是最后一个音符，歌曲结束 (or invalid duration on last note)
                                state <= S_IDLE;
                            end
                        end else if (note_duration_timer >= (BASIC_NOTE_DURATION_CYCLES * current_note_duration_units) - 1'b1 ) begin // 当前音符播放时长已到
                            // 切换到下一个音符
                            if (current_note_index < SONG_LENGTH - 1) begin
                                current_note_index <= current_note_index + 1;
                                // Read next note including octave for the *next* cycle
                                {current_octave_code_from_rom, current_note_id_from_rom, current_note_duration_units} = song_rom[current_note_index + 1]; // This reads for the upcoming note

                                song_key_id <= current_note_id_from_rom;
                                song_key_is_pressed <= (current_note_id_from_rom != REST);
                                song_octave_up_feed <= (current_octave_code_from_rom == OCTAVE_HIGH);
                                song_octave_down_feed <= (current_octave_code_from_rom == OCTAVE_LOW);
                                note_duration_timer <= 0; // Reset timer for the new note
                            end else begin // 已经是最后一个音符，歌曲结束
                                state <= S_IDLE;
                                // Optional: keep the last note sounding until button release or explicitly silence here.
                                // Current logic will go to IDLE, which silences.
                            end
                        end else begin // 当前音符还未播完
                            note_duration_timer <= note_duration_timer + 1; // 继续计时
                            // Outputs (key_id, is_pressed, octave_feeds) remain for the current note
                        end
                    end else begin
                        // 如果在S_PLAYING状态时play_active_level变为低
                        state <= S_IDLE;          // 强制回到IDLE
                        song_key_is_pressed <= 1'b0; // 静音
                        song_octave_up_feed <= 1'b0;
                        song_octave_down_feed <= 1'b0;
                        is_song_playing <= 1'b0;    // 更新状态
                    end
                end // S_PLAYING 结束

                default: state <= S_IDLE; // 意外状态则回到IDLE
            endcase // case(state) 结束
        end // else (if !rst_n) 结束
    end // always 结束
endmodule // 模块结束
```

### scrolling_display_buffer.v
```verilog
// File: scrolling_display_buffer.v
// Module to manage a 6-digit scrolling buffer for note display (SEG1-SEG6)

module scrolling_display_buffer (
    input clk,
    input rst_n,

    input new_note_valid_pulse,         // Single clock pulse when a new valid note is pressed
    input [2:0] current_base_note_id_in,  // The base note ID (1-7) of the new note

    output reg [2:0] display_data_seg1, // Data for physical SEG1 (rightmost of scrolling area)
    output reg [2:0] display_data_seg2,
    output reg [2:0] display_data_seg3,
    output reg [2:0] display_data_seg4,
    output reg [2:0] display_data_seg5,
    output reg [2:0] display_data_seg6  // Data for physical SEG6 (leftmost of scrolling area)
);

// Internal buffer registers for 6 display segments (SEG1 to SEG6)
// seg_buffer[0] corresponds to display_data_seg1 (rightmost of scrolling)
// seg_buffer[5] corresponds to display_data_seg6 (leftmost of scrolling)
reg [2:0] seg_buffer [0:5]; // Each element stores a 3-bit note ID (0 for blank)

integer i; // Loop variable

initial begin
    display_data_seg1 = 3'd0;
    display_data_seg2 = 3'd0;
    display_data_seg3 = 3'd0;
    display_data_seg4 = 3'd0;
    display_data_seg5 = 3'd0;
    display_data_seg6 = 3'd0;
    for (i = 0; i < 6; i = i + 1) begin
        seg_buffer[i] = 3'd0; // Initialize buffer to blank
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all buffer positions to 0 (blank)
        for (i = 0; i < 6; i = i + 1) begin
            seg_buffer[i] <= 3'd0;
        end
    end else begin
        if (new_note_valid_pulse) begin
            // Scroll existing data: seg_buffer[5] (SEG6) <- seg_buffer[4] (SEG5), etc.
            // The oldest data at seg_buffer[5] is shifted out.
            seg_buffer[5] <= seg_buffer[4]; // SEG6_data <--- SEG5_data
            seg_buffer[4] <= seg_buffer[3]; // SEG5_data <--- SEG4_data
            seg_buffer[3] <= seg_buffer[2]; // SEG4_data <--- SEG3_data
            seg_buffer[2] <= seg_buffer[1]; // SEG3_data <--- SEG2_data
            seg_buffer[1] <= seg_buffer[0]; // SEG2_data <--- SEG1_data

            // Load new note into the first position (SEG1)
            seg_buffer[0] <= current_base_note_id_in; // SEG1_data <--- New Note
        end
        // No else: if new_note_valid_pulse is not high, the buffer holds its value.
    end
end

// Assign buffer contents to outputs continuously
// (Combinational assignment from buffer regs to output regs for clarity,
// or could directly use seg_buffer[x] in seven_segment_controller if preferred as wires)
// For direct output from registers, assign in the always block or use separate assigns.
// To ensure outputs are also reset correctly and avoid latches if outputs were wires,
// it's cleaner to assign them from the registered buffer values.

// We declared outputs as 'reg' and will assign them directly.
// Let's ensure they are updated in the clocked block or from the buffer
// in a combinational way if they were wires.
// Since outputs are 'reg', we update them based on the 'seg_buffer'.
// It's often good practice for module outputs driven by internal registers
// to be assigned combinatorially *from* those registers,
// or the outputs themselves are the registers.
// Here, we've made outputs 'reg', so we should assign them in an always block.
// A simpler way if outputs are 'reg' is to directly assign in the clocked block AFTER buffer update.

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        display_data_seg1 <= 3'd0;
        display_data_seg2 <= 3'd0;
        display_data_seg3 <= 3'd0;
        display_data_seg4 <= 3'd0;
        display_data_seg5 <= 3'd0;
        display_data_seg6 <= 3'd0;
    end else begin
        // Update outputs from the buffer contents
        display_data_seg1 <= seg_buffer[0];
        display_data_seg2 <= seg_buffer[1];
        display_data_seg3 <= seg_buffer[2];
        display_data_seg4 <= seg_buffer[3];
        display_data_seg5 <= seg_buffer[4];
        display_data_seg6 <= seg_buffer[5];
    end
end

endmodule
```

### mode_sequencer.v
```verilog
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
```
### practice_player.v
```verilog
// File: practice_player.v (Reconstructed Complete Version)
module practice_player #(
    parameter NUM_DISPLAY_SEGMENTS = 6
) (
    input clk,
    input rst_n,

    input practice_mode_active,
    input [3:0] current_live_key_id,
    input current_live_key_pressed,

    output reg [2:0] display_out_seg0,
    output reg [2:0] display_out_seg1,
    output reg [2:0] display_out_seg2,
    output reg [2:0] display_out_seg3,
    output reg [2:0] display_out_seg4,
    output reg [2:0] display_out_seg5,

    output reg correct_note_played_event,
    output reg wrong_note_played_event,
    output reg practice_song_finished_event
);

// --- Parameters ---
localparam PRACTICE_SONG_LENGTH = 14;

// --- Functions ---
function [3:0] get_practice_song_note (input integer index);
    if (index >= PRACTICE_SONG_LENGTH || index < 0) begin
        get_practice_song_note = 4'd0; 
    end else begin
        case (index)
            0:  get_practice_song_note = 4'd1; 1:  get_practice_song_note = 4'd1;
            2:  get_practice_song_note = 4'd5; 3:  get_practice_song_note = 4'd5;
            4:  get_practice_song_note = 4'd6; 5:  get_practice_song_note = 4'd6;
            6:  get_practice_song_note = 4'd5; 7:  get_practice_song_note = 4'd4;
            8:  get_practice_song_note = 4'd4; 9:  get_practice_song_note = 4'd3;
            10: get_practice_song_note = 4'd3; 11: get_practice_song_note = 4'd2;
            12: get_practice_song_note = 4'd2; 13: get_practice_song_note = 4'd1;
            default: get_practice_song_note = 4'd0;
        endcase
    end
endfunction

function [2:0] musical_to_display_id (input [3:0] musical_id);
    case (musical_id)
        4'd1:  musical_to_display_id = 3'd1; 4'd2:  musical_to_display_id = 3'd2;
        4'd3:  musical_to_display_id = 3'd3; 4'd4:  musical_to_display_id = 3'd4;
        4'd5:  musical_to_display_id = 3'd5; 4'd6:  musical_to_display_id = 3'd6;
        4'd7:  musical_to_display_id = 3'd7;
        default: musical_to_display_id = 3'd0;
    endcase
endfunction

// --- Internal Registers ---
reg [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] current_note_index_in_song;
reg current_live_key_pressed_prev;
reg [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] next_note_idx_calculated; // Moved declaration to module level

// --- Wires ---
wire new_key_press_event;

// --- Tasks ---
task update_display_buffer (input [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] base_song_idx_for_display);
    integer i;
    integer song_idx_to_show;
    reg [2:0] temp_display_buffer [NUM_DISPLAY_SEGMENTS-1:0];
    begin // Task body begin
        for (i = 0; i < NUM_DISPLAY_SEGMENTS; i = i + 1) begin // For loop begin
            song_idx_to_show = base_song_idx_for_display + i;
            if (song_idx_to_show < PRACTICE_SONG_LENGTH) begin // If begin
                temp_display_buffer[i] = musical_to_display_id(get_practice_song_note(song_idx_to_show));
            end else begin // Else for if begin
                temp_display_buffer[i] = 3'd0;
            end // If else end
        end // For loop end
        display_out_seg0 <= temp_display_buffer[0]; display_out_seg1 <= temp_display_buffer[1];
        display_out_seg2 <= temp_display_buffer[2]; display_out_seg3 <= temp_display_buffer[3];
        display_out_seg4 <= temp_display_buffer[4]; display_out_seg5 <= temp_display_buffer[5];
    end // Task body end
endtask

// --- Initial block ---
initial begin
    current_note_index_in_song = 0;
    correct_note_played_event = 1'b0; wrong_note_played_event = 1'b0;
    practice_song_finished_event = 1'b0;
    display_out_seg0 = 3'd0; display_out_seg1 = 3'd0; display_out_seg2 = 3'd0;
    display_out_seg3 = 3'd0; display_out_seg4 = 3'd0; display_out_seg5 = 3'd0;
    current_live_key_pressed_prev = 1'b0;
    next_note_idx_calculated = 0; // Initialize module level reg
end

// --- Combinational logic for new_key_press_event ---
assign new_key_press_event = current_live_key_pressed && !current_live_key_pressed_prev;

// --- Sequential logic for current_live_key_pressed_prev ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_live_key_pressed_prev <= 1'b0;
    end else begin
        current_live_key_pressed_prev <= current_live_key_pressed;
    end
end

// --- Main sequential logic block ---
always @(posedge clk or negedge rst_n) begin
    // 'next_note_idx_calculated' is a module-level reg, assigned before use in this block.
    if (!rst_n) begin
        current_note_index_in_song <= 0;
        correct_note_played_event <= 1'b0; wrong_note_played_event <= 1'b0;
        practice_song_finished_event <= 1'b0;
        update_display_buffer(0);
    end else begin
        correct_note_played_event <= 1'b0;
        wrong_note_played_event <= 1'b0;

        if (practice_mode_active) begin
            if (new_key_press_event && current_live_key_id != 4'd0) begin
                if (current_note_index_in_song < PRACTICE_SONG_LENGTH) begin
                    if (current_live_key_id == get_practice_song_note(current_note_index_in_song)) begin
                        correct_note_played_event <= 1'b1;
                        
                        next_note_idx_calculated = current_note_index_in_song + 1; // Assignment

                        if (current_note_index_in_song == PRACTICE_SONG_LENGTH - 1) begin
                            practice_song_finished_event <= 1'b1;
                        end // end if (current_note_index_in_song == ...)
                        
                        current_note_index_in_song <= next_note_idx_calculated; // Usage
                        update_display_buffer(next_note_idx_calculated);      // Usage
                    end else begin // else for if (current_live_key_id == ...)
                        wrong_note_played_event <= 1'b1;
                    end // end if (current_live_key_id == ...) else
                end // end if (current_note_index_in_song < ...)
            end // end if (new_key_press_event && ...)
        end else begin // else for if (practice_mode_active)
            if (current_note_index_in_song != 0) begin
                 current_note_index_in_song <= 0;
                 update_display_buffer(0);
            end // end if (current_note_index_in_song != 0)
            if (practice_song_finished_event) begin
                practice_song_finished_event <= 1'b0;
            end // end if (practice_song_finished_event)
        end // end if (practice_mode_active) else
    end // end if (!rst_n) else
end // end always

endmodule
```
