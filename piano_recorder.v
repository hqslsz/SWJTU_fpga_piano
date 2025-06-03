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