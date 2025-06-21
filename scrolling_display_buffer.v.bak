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