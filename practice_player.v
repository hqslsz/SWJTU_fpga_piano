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