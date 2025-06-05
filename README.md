# fpga
SWJTU数电课设电子琴

## 核心代码
### 顶层fpga.v
```verilog
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