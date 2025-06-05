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
        song_rom[3]  = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[4]  = {OCTAVE_LOW,  NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2858s
        song_rom[5]  = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[6]  = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[7]  = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[8]  = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[9]  = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[10] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[11] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[12] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[13] = {OCTAVE_MID,  NOTE_C,   4'd2}; // MIDI 60 (C4), Dur: 0.1429s
        song_rom[14] = {OCTAVE_MID,  NOTE_E,   4'd2}; // MIDI 64 (E4), Dur: 0.1428s
        song_rom[15] = {OCTAVE_MID,  NOTE_D,   4'd2}; // MIDI 62 (D4), Dur: 0.1429s
        song_rom[16] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[17] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[18] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[19] = {OCTAVE_MID,  NOTE_D,   4'd2}; // MIDI 62 (D4), Dur: 0.1428s
        song_rom[20] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[21] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[22] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[23] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[24] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[25] = {OCTAVE_LOW,  NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1429s
        song_rom[26] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[27] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[28] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[29] = {OCTAVE_LOW,  NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2857s
        song_rom[30] = {OCTAVE_LOW,  NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1429s
        song_rom[31] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[32] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[33] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[34] = {OCTAVE_LOW,  NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s
        song_rom[35] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[36] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[37] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[38] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[39] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[40] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[41] = {OCTAVE_LOW,  NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 59 note_off time=192)
        song_rom[42] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[43] = {OCTAVE_MID,  NOTE_C,   4'd2}; // MIDI 60 (C4), Dur: 0.1428s
        song_rom[44] = {OCTAVE_MID,  NOTE_D,   4'd2}; // MIDI 62 (D4), Dur: 0.1429s
        song_rom[45] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[46] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[47] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[48] = {OCTAVE_MID,  NOTE_E,   4'd2}; // MIDI 64 (E4), Dur: 0.1428s
        song_rom[49] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[50] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[51] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[52] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[53] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[54] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[55] = {OCTAVE_LOW,  NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1428s
        song_rom[56] = {OCTAVE_LOW,  NOTE_G,   4'd8}; // MIDI 55 (G3), Dur: 0.5714s (Msg 81 note_off time=384)
        song_rom[57] = {OCTAVE_LOW,  NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1429s
        song_rom[58] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[59] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[60] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[61] = {OCTAVE_LOW,  NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s
        song_rom[62] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[63] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[64] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[65] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[66] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[67] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[68] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[69] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[70] = {OCTAVE_MID,  NOTE_C,   4'd2}; // MIDI 60 (C4), Dur: 0.1429s
        song_rom[71] = {OCTAVE_MID,  NOTE_E,   4'd2}; // MIDI 64 (E4), Dur: 0.1428s
        song_rom[72] = {OCTAVE_MID,  NOTE_D,   4'd2}; // MIDI 62 (D4), Dur: 0.1429s
        song_rom[73] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[74] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[75] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[76] = {OCTAVE_MID,  NOTE_D,   4'd2}; // MIDI 62 (D4), Dur: 0.1428s
        song_rom[77] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[78] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[79] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[80] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[81] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[82] = {OCTAVE_LOW,  NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1429s
        song_rom[83] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[84] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[85] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[86] = {OCTAVE_LOW,  NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2857s
        song_rom[87] = {OCTAVE_LOW,  NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1429s
        song_rom[88] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[89] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[90] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[91] = {OCTAVE_LOW,  NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s
        song_rom[92] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[93] = {OCTAVE_LOW,  NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[94] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[95] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[96] = {OCTAVE_LOW,  NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[97] = {OCTAVE_MID,  REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[98] = {OCTAVE_LOW,  NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 139)
        song_rom[99] = {OCTAVE_LOW,  NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[100] = {OCTAVE_MID, NOTE_C,   4'd2}; // MIDI 60 (C4), Dur: 0.1429s
        song_rom[101] = {OCTAVE_MID, NOTE_D,   4'd2}; // MIDI 62 (D4), Dur: 0.1429s
        song_rom[102] = {OCTAVE_MID, REST,     4'd2}; // Rest dur: 0.1428s
        song_rom[103] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[104] = {OCTAVE_MID, REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[105] = {OCTAVE_MID, NOTE_E,   4'd2}; // MIDI 64 (E4), Dur: 0.1428s
        song_rom[106] = {OCTAVE_MID, REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[107] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[108] = {OCTAVE_MID, REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[109] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[110] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[111] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[112] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1428s
        song_rom[113] = {OCTAVE_LOW, NOTE_G,   4'd8}; // MIDI 55 (G3), Dur: 0.5714s (Msg 161)
        song_rom[114] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1429s
        song_rom[115] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[116] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[117] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[118] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s
        song_rom[119] = {OCTAVE_MID, REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[120] = {OCTAVE_MID, NOTE_D,   4'd4}; // MIDI 62 (D4), Dur: 0.2857s (Msg 173)
        song_rom[121] = {OCTAVE_MID, NOTE_CS,  4'd4}; // MIDI 61 (C#4), Dur: 0.2857s (Msg 175)
        song_rom[122] = {OCTAVE_MID, NOTE_E,   4'd4}; // MIDI 64 (E4), Dur: 0.2857s (Msg 177)
        song_rom[123] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 179)
        song_rom[124] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s
        song_rom[125] = {OCTAVE_MID, NOTE_CS,  4'd2}; // MIDI 61 (C#4), Dur: 0.1428s
        song_rom[126] = {OCTAVE_MID, NOTE_D,   4'd4}; // MIDI 62 (D4), Dur: 0.2857s (Msg 185)
        song_rom[127] = {OCTAVE_LOW, NOTE_B,   4'd4}; // MIDI 59 (B3), Dur: 0.2857s (Msg 187)
        song_rom[128] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 189)
        song_rom[129] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s (Msg 191)
        song_rom[130] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s (Msg 193)
        song_rom[131] = {OCTAVE_LOW, NOTE_E,   4'd2}; // MIDI 52 (E3), Dur: 0.1428s
        song_rom[132] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[133] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s (Msg 199)
        song_rom[134] = {OCTAVE_LOW, NOTE_D,   4'd4}; // MIDI 50 (D3), Dur: 0.2857s (Msg 201)
        song_rom[135] = {OCTAVE_LOW, NOTE_CS,  4'd4}; // MIDI 49 (C#3), Dur: 0.2857s (Msg 203)
        song_rom[136] = {OCTAVE_LOW, NOTE_D,   4'd4}; // MIDI 50 (D3), Dur: 0.2857s (Msg 205)
        song_rom[137] = {OCTAVE_LOW, NOTE_E,   4'd6}; // MIDI 52 (E3), Dur: 0.4286s (Msg 207)
        song_rom[138] = {OCTAVE_LOW, NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1429s
        song_rom[139] = {OCTAVE_LOW, NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2857s (Msg 211)
        song_rom[140] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s (Msg 213)
        song_rom[141] = {OCTAVE_LOW, NOTE_G,   4'd6}; // MIDI 55 (G3), Dur: 0.4286s (Msg 215)
        song_rom[142] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1428s
        song_rom[143] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s (Msg 219)
        song_rom[144] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 221)
        song_rom[145] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[146] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[147] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1428s
        song_rom[148] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1429s
        song_rom[149] = {OCTAVE_LOW, NOTE_E,   4'd2}; // MIDI 52 (E3), Dur: 0.1428s
        song_rom[150] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1429s
        song_rom[151] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[152] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1428s
        song_rom[153] = {OCTAVE_LOW, NOTE_E,   4'd8}; // MIDI 52 (E3), Dur: 0.5714s (Msg 239)
        song_rom[154] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1428s
        song_rom[155] = {OCTAVE_LOW, NOTE_G,   4'd2}; // MIDI 55 (G3), Dur: 0.1429s
        song_rom[156] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[157] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[158] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1429s
        song_rom[159] = {OCTAVE_MID, REST,     4'd2}; // Rest dur: 0.1429s
        song_rom[160] = {OCTAVE_MID, NOTE_D,   4'd4}; // MIDI 62 (D4), Dur: 0.2857s (Msg 251)
        song_rom[161] = {OCTAVE_MID, NOTE_CS,  4'd4}; // MIDI 61 (C#4), Dur: 0.2857s (Msg 253)
        song_rom[162] = {OCTAVE_MID, NOTE_E,   4'd4}; // MIDI 64 (E4), Dur: 0.2857s (Msg 255)
        song_rom[163] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 257)
        song_rom[164] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1428s
        song_rom[165] = {OCTAVE_MID, NOTE_CS,  4'd2}; // MIDI 61 (C#4), Dur: 0.1429s
        song_rom[166] = {OCTAVE_MID, NOTE_D,   4'd4}; // MIDI 62 (D4), Dur: 0.2857s (Msg 263)
        song_rom[167] = {OCTAVE_LOW, NOTE_B,   4'd4}; // MIDI 59 (B3), Dur: 0.2857s (Msg 265)
        song_rom[168] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s (Msg 267)
        song_rom[169] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s (Msg 269)
        song_rom[170] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s (Msg 271)
        song_rom[171] = {OCTAVE_LOW, NOTE_GS,  4'd4}; // MIDI 56 (G#3), Dur: 0.2857s (Msg 273, note 56 is G#)
        song_rom[172] = {OCTAVE_LOW, NOTE_A,   4'd8}; // MIDI 57 (A3), Dur: 0.5714s (Msg 275)
        song_rom[173] = {OCTAVE_LOW, NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2857s (Msg 277)
        song_rom[174] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s (Msg 279)
        song_rom[175] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s (Msg 281)
        song_rom[176] = {OCTAVE_LOW, NOTE_D,   4'd4}; // MIDI 50 (D3), Dur: 0.2857s (Msg 283)

        // Msg 284: note_on note=52 time=1 (Abs Time: 33.1428s) (Small delta, effectively concurrent with previous note_off for calculation)
        // Msg 285: note_off note=52 time=288 (Abs Time: 33.5714s)
        // Note: MIDI 52 (E3). Start: 33.1428, End: 33.5714. Dur: 0.4286s -> 6 units
        // Rest before: 33.1428 - 33.1413 (end of prev D3) = 0.0015s -> 0 units. (No explicit rest)
        song_rom[177] = {OCTAVE_LOW, NOTE_E,   4'd6}; // MIDI 52 (E3), Dur: 0.4286s

        // Msg 286: note_off note=52 time=95 (Abs Time: 33.7128s) - This is an extra note_off, seems like MIDI data might be a bit messy.
        // Or it implies a very short rest. Given the next note_on for 52 is at 33.7128s, we ignore this as a rest creator.

        // Msg 287: note_on note=52 time=0 (Abs Time: 33.7128s)
        // Msg 288: note_on note=52 time=1 (Abs Time: 33.7143s) - Another one immediately? Take first on.
        // Msg 289: note_on note=50 time=287 (Abs Time: 34.1413s)
        // Msg 290: note_off note=52 time=1 (Abs Time: 34.1428s) - Let's assume this OFF is for the ON at 33.7128s
        // Note: MIDI 52 (E3). Start: 33.7128, End: 34.1428. Dur: 0.4300s -> 6 units
        // Rest before: 33.7128 - 33.5714 = 0.1414s -> 2 units
        song_rom[178] = {OCTAVE_MID, REST,     4'd2};
        song_rom[179] = {OCTAVE_LOW, NOTE_E,   4'd6}; // MIDI 52 (E3), Dur: 0.4300s

        // Msg 289 was ON for 50, Msg 291 is OFF for 50.
        // Note: MIDI 50 (D3). Start: 34.1413, End: 34.2842. Dur: 0.1429s -> 2 units
        // Rest before: 34.1413 - 34.1428 (end of E3) = ~0s (No explicit rest)
        song_rom[180] = {OCTAVE_LOW, NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1429s

        // Msg 292: note_on note=52 time=0 (Abs Time: 34.2842s)
        // Msg 293: note_off note=52 time=192 (Abs Time: 34.5699s)
        // Note: MIDI 52 (E3). Start: 34.2842, End: 34.5699. Dur: 0.2857s -> 4 units
        // Rest before: 34.2842 - 34.2842 = 0 (No explicit rest)
        song_rom[181] = {OCTAVE_LOW, NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2857s

        // Msg 294: note_on note=55 time=0 (Abs Time: 34.5699s)
        // Msg 295: note_off note=55 time=192 (Abs Time: 34.8556s)
        // Note: MIDI 55 (G3). Dur: 0.2857s -> 4 units
        song_rom[182] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 296: note_on note=54 time=0 (Abs Time: 34.8556s)
        // Msg 297: note_off note=54 time=192 (Abs Time: 35.1413s)
        // Note: MIDI 54 (F#3). Dur: 0.2857s -> 4 units
        song_rom[183] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s

        // Msg 298: note_on note=50 time=0 (Abs Time: 35.1413s)
        // Msg 299: note_off note=50 time=192 (Abs Time: 35.4270s)
        // Note: MIDI 50 (D3). Dur: 0.2857s -> 4 units
        song_rom[184] = {OCTAVE_LOW, NOTE_D,   4'd4}; // MIDI 50 (D3), Dur: 0.2857s

        // Msg 300: note_on note=52 time=1 (Abs Time: 35.4285s)
        // Msg 301: note_off note=52 time=288 (Abs Time: 35.8571s)
        // Note: MIDI 52 (E3). Dur: 0.4286s -> 6 units
        song_rom[185] = {OCTAVE_LOW, NOTE_E,   4'd6}; // MIDI 52 (E3), Dur: 0.4286s

        // Msg 302: note_off note=52 ... (Abs Time: 35.9985s) - Another off
        // Msg 303: note_on note=52 ... (Abs Time: 35.9985s)
        // Msg 304: note_on note=52 ... (Abs Time: 35.9985s)
        // Msg 305: note_off note=52 ... (Abs Time: 36.5699s)
        // Note: MIDI 52 (E3). Start: 35.9985, End: 36.5699. Dur: 0.5714s -> 8 units
        // Rest before: 35.9985 - 35.8571 = 0.1414s -> 2 units
        song_rom[186] = {OCTAVE_MID, REST,     4'd2};
        song_rom[187] = {OCTAVE_LOW, NOTE_E,   4'd8}; // MIDI 52 (E3), Dur: 0.5714s

        // Msg 306: note_on note=55 time=0 (Abs Time: 36.5699s)
        // Msg 307: note_off note=55 time=192 (Abs Time: 36.8556s)
        // Note: MIDI 55 (G3). Dur: 0.2857s -> 4 units
        song_rom[188] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 308: note_on note=59 time=0 (Abs Time: 36.8556s)
        // Msg 309: note_off note=59 time=192 (Abs Time: 37.1413s)
        // Note: MIDI 59 (B3). Dur: 0.2857s -> 4 units
        song_rom[189] = {OCTAVE_LOW, NOTE_B,   4'd4}; // MIDI 59 (B3), Dur: 0.2857s

        // Msg 310: note_on note=57 time=0 (Abs Time: 37.1413s)
        // Msg 311: note_off note=57 time=192 (Abs Time: 37.4270s)
        // Note: MIDI 57 (A3). Dur: 0.2857s -> 4 units
        song_rom[190] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s

        // Msg 312: note_on note=54 time=0 (Abs Time: 37.4270s)
        // Msg 313: note_off note=54 time=192 (Abs Time: 37.7128s)
        // Note: MIDI 54 (F#3). Dur: 0.2857s -> 4 units
        song_rom[191] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s

        // Msg 314: note_on note=55 time=1 (Abs Time: 37.7142s)
        // Msg 315: note_off note=55 time=288 (Abs Time: 38.1428s)
        // Note: MIDI 55 (G3). Dur: 0.4286s -> 6 units
        song_rom[192] = {OCTAVE_LOW, NOTE_G,   4'd6}; // MIDI 55 (G3), Dur: 0.4286s

        // Msg 317: note_on note=55 (Abs Time: 38.2842s)
        // Msg 318: note_on note=55 (Abs Time: 38.2857s)
        // Msg 319: note_on note=54 (Abs Time: 38.7128s)
        // Msg 320: note_off note=55 (Abs Time: 38.7142s) for ON at 38.2842s
        // Note: MIDI 55 (G3). Start: 38.2842, End: 38.7142. Dur: 0.4300s -> 6 units
        // Rest before: 38.2842 - 38.1428 = 0.1414s -> 2 units
        song_rom[193] = {OCTAVE_MID, REST,     4'd2};
        song_rom[194] = {OCTAVE_LOW, NOTE_G,   4'd6}; // MIDI 55 (G3), Dur: 0.4300s

        // Msg 319 was ON for 54, Msg 321 is OFF for 54.
        // Note: MIDI 54 (F#3). Start: 38.7128, End: 38.8556. Dur: 0.1428s -> 2 units
        // Rest before: 38.7128 - 38.7142 = ~0s
        song_rom[195] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1428s

        // Msg 322: note_on note=55 (Abs Time: 38.8556s)
        // Msg 323: note_off note=55 (Abs Time: 39.1413s)
        // Note: MIDI 55 (G3). Dur: 0.2857s -> 4 units
        song_rom[196] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 324: note_on note=59 (Abs Time: 39.1413s)
        // Msg 325: note_off note=59 (Abs Time: 39.4270s)
        // Note: MIDI 59 (B3). Dur: 0.2857s -> 4 units
        song_rom[197] = {OCTAVE_LOW, NOTE_B,   4'd4}; // MIDI 59 (B3), Dur: 0.2857s

        // Msg 326: note_on note=57 (Abs Time: 39.4270s)
        // Msg 327: note_off note=57 (Abs Time: 39.7128s)
        // Note: MIDI 57 (A3). Dur: 0.2858s -> 4 units
        song_rom[198] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2858s

        // Msg 328: note_on note=54 (Abs Time: 39.7128s)
        // Msg 329: note_off note=54 (Abs Time: 39.9985s)
        // Note: MIDI 54 (F#3). Dur: 0.2857s -> 4 units
        song_rom[199] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s

        // Msg 330: note_on note=55 (Abs Time: 39.9985s)
        // Msg 331: note_off note=55 (Abs Time: 40.5699s)
        // Note: MIDI 55 (G3). Dur: 0.5714s -> 8 units
        song_rom[200] = {OCTAVE_LOW, NOTE_G,   4'd8}; // MIDI 55 (G3), Dur: 0.5714s

        // Msg 332: note_on note=55 (Abs Time: 40.5699s)
        // Msg 333: note_off note=55 (Abs Time: 41.1413s)
        // Note: MIDI 55 (G3). Dur: 0.5714s -> 8 units
        song_rom[201] = {OCTAVE_LOW, NOTE_G,   4'd8}; // MIDI 55 (G3), Dur: 0.5714s

        // Msg 334: note_on note=52 (Abs Time: 41.1413s)
        // Msg 335: note_off note=52 (Abs Time: 41.4270s)
        // Note: MIDI 52 (E3). Dur: 0.2857s -> 4 units
        song_rom[202] = {OCTAVE_LOW, NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2857s

        // Msg 336: note_on note=55 (Abs Time: 41.4270s)
        // Msg 337: note_off note=55 (Abs Time: 41.7128s)
        // Note: MIDI 55 (G3). Dur: 0.2858s -> 4 units
        song_rom[203] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2858s

        // Msg 338: note_on note=54 (Abs Time: 41.7128s)
        // Msg 339: note_off note=54 (Abs Time: 41.9985s)
        // Note: MIDI 54 (F#3). Dur: 0.2857s -> 4 units
        song_rom[204] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s

        // Msg 340: note_on note=50 (Abs Time: 41.9985s)
        // Msg 341: note_off note=50 (Abs Time: 42.2842s)
        // Note: MIDI 50 (D3). Dur: 0.2857s -> 4 units
        song_rom[205] = {OCTAVE_LOW, NOTE_D,   4'd4}; // MIDI 50 (D3), Dur: 0.2857s

        // Msg 342: note_on note=52 (Abs Time: 42.2842s)
        // Msg 343: note_off note=52 (Abs Time: 42.8556s)
        // Note: MIDI 52 (E3). Dur: 0.5714s -> 8 units
        song_rom[206] = {OCTAVE_LOW, NOTE_E,   4'd8}; // MIDI 52 (E3), Dur: 0.5714s

        // Msg 344: note_on note=52 (Abs Time: 42.8556s)
        // Msg 345: note_off note=52 (Abs Time: 43.2842s)
        // Note: MIDI 52 (E3). Dur: 0.4286s -> 6 units
        song_rom[207] = {OCTAVE_LOW, NOTE_E,   4'd6}; // MIDI 52 (E3), Dur: 0.4286s

        // Msg 346: note_on note=50 (Abs Time: 43.2842s)
        // Msg 347: note_off note=50 (Abs Time: 43.4270s)
        // Note: MIDI 50 (D3). Dur: 0.1428s -> 2 units
        song_rom[208] = {OCTAVE_LOW, NOTE_D,   4'd2}; // MIDI 50 (D3), Dur: 0.1428s

        // Msg 348: note_on note=52 (Abs Time: 43.4270s)
        // Msg 349: note_off note=52 (Abs Time: 43.7128s)
        // Note: MIDI 52 (E3). Dur: 0.2858s -> 4 units
        song_rom[209] = {OCTAVE_LOW, NOTE_E,   4'd4}; // MIDI 52 (E3), Dur: 0.2858s

        // Msg 350: note_on note=55 (Abs Time: 43.7128s)
        // Msg 351: note_off note=55 (Abs Time: 43.9985s)
        // Note: MIDI 55 (G3). Dur: 0.2857s -> 4 units
        song_rom[210] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 352: note_on note=54 (Abs Time: 43.9985s)
        // Msg 353: note_off note=54 (Abs Time: 44.2842s)
        // Note: MIDI 54 (F#3). Dur: 0.2857s -> 4 units
        song_rom[211] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s

        // Msg 354: note_on note=50 (Abs Time: 44.2842s)
        // Msg 355: note_off note=50 (Abs Time: 44.5699s)
        // Note: MIDI 50 (D3). Dur: 0.2857s -> 4 units
        song_rom[212] = {OCTAVE_LOW, NOTE_D,   4'd4}; // MIDI 50 (D3), Dur: 0.2857s

        // Msg 356: note_on note=52 (Abs Time: 44.5714s)
        // Msg 357: note_off note=52 (Abs Time: 45.1413s)
        // Note: MIDI 52 (E3). Dur: 0.5699s -> 8 units
        song_rom[213] = {OCTAVE_LOW, NOTE_E,   4'd8}; // MIDI 52 (E3), Dur: 0.5699s

        // Msg 358: note_on note=52 (Abs Time: 45.1413s) - effectively same as prev off
        // Msg 359: note_off note=52 (Abs Time: 45.1428s) - very short note, ~0s. Ignore or merge.
        // For simplicity, let's treat the next significant note.

        // Msg 360: note_on note=52 (Abs Time: 45.1428s)
        // Msg 361: note_on note=55 (Abs Time: 45.7128s)
        // Msg 362: note_off note=52 (Abs Time: 45.7142s)
        // Note: MIDI 52 (E3). Start: 45.1428, End: 45.7142. Dur: 0.5714s -> 8 units
        // (Rest from 45.1413 to 45.1428 is negligible)
        song_rom[214] = {OCTAVE_LOW, NOTE_E,   4'd8}; // MIDI 52 (E3), Dur: 0.5714s

        // Msg 361 was ON for 55, Msg 363 is OFF for 55.
        // Note: MIDI 55 (G3). Start: 45.7128, End: 45.9985. Dur: 0.2857s -> 4 units
        // Rest: 45.7128 - 45.7142 (negligible negative or zero)
        song_rom[215] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 364: note_on note=59 (Abs Time: 45.9985s)
        // Msg 365: note_off note=59 (Abs Time: 46.2842s)
        // Note: MIDI 59 (B3). Dur: 0.2857s -> 4 units
        song_rom[216] = {OCTAVE_LOW, NOTE_B,   4'd4}; // MIDI 59 (B3), Dur: 0.2857s

        // Msg 366: note_on note=57 (Abs Time: 46.2842s)
        // Msg 367: note_off note=57 (Abs Time: 46.5699s)
        // Note: MIDI 57 (A3). Dur: 0.2857s -> 4 units
        song_rom[217] = {OCTAVE_LOW, NOTE_A,   4'd4}; // MIDI 57 (A3), Dur: 0.2857s

        // Msg 368: note_on note=54 (Abs Time: 46.5699s)
        // Msg 369: note_off note=54 (Abs Time: 46.8556s)
        // Note: MIDI 54 (F#3). Dur: 0.2857s -> 4 units
        song_rom[218] = {OCTAVE_LOW, NOTE_FS,  4'd4}; // MIDI 54 (F#3), Dur: 0.2857s

        // Msg 370: note_on note=55 (Abs Time: 46.8571s)
        // Msg 371: note_off note=55 (Abs Time: 47.2857s)
        // Note: MIDI 55 (G3). Dur: 0.4286s -> 6 units
        song_rom[219] = {OCTAVE_LOW, NOTE_G,   4'd6}; // MIDI 55 (G3), Dur: 0.4286s

        // Msg 373: note_on note=55 (Abs Time: 47.4270s)
        // Msg 374: note_on note=55 (Abs Time: 47.4285s)
        // Msg 375: note_on note=54 (Abs Time: 47.8556s)
        // Msg 376: note_off note=55 (Abs Time: 47.8571s) for ON at 47.4270s
        // Note: MIDI 55 (G3). Start: 47.4270, End: 47.8571. Dur: 0.4301s -> 6 units
        // Rest before: 47.4270 - 47.2857 = 0.1413s -> 2 units
        song_rom[220] = {OCTAVE_MID, REST,     4'd2};
        song_rom[221] = {OCTAVE_LOW, NOTE_G,   4'd6}; // MIDI 55 (G3), Dur: 0.4301s

        // Msg 375 was ON for 54, Msg 377 is OFF for 54.
        // Note: MIDI 54 (F#3). Start: 47.8556, End: 47.9985. Dur: 0.1429s -> 2 units
        // Rest: 47.8556 - 47.8571 (negligible)
        song_rom[222] = {OCTAVE_LOW, NOTE_FS,  4'd2}; // MIDI 54 (F#3), Dur: 0.1429s

        // Msg 378: note_on note=55 (Abs Time: 47.9985s)
        // Msg 379: note_off note=55 (Abs Time: 48.2842s)
        // Note: MIDI 55 (G3). Dur: 0.2857s -> 4 units
        song_rom[223] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 380: note_on note=59 (Abs Time: 48.2842s)
        // Msg 381: note_off note=59 (Abs Time: 48.5699s)
        // Note: MIDI 59 (B3). Dur: 0.2857s -> 4 units
        song_rom[224] = {OCTAVE_LOW, NOTE_B,   4'd4}; // MIDI 59 (B3), Dur: 0.2857s

        // Msg 382: note_on note=57 (Abs Time: 48.5699s)
        // Msg 383: note_off note=57 (Abs Time: 48.7127s)
        // Note: MIDI 57 (A3). Dur: 0.1428s -> 2 units
        song_rom[225] = {OCTAVE_LOW, NOTE_A,   4'd2}; // MIDI 57 (A3), Dur: 0.1428s

        // Msg 384: note_on note=59 (Abs Time: 48.7127s)
        // Msg 385: note_off note=59 (Abs Time: 48.8556s)
        // Note: MIDI 59 (B3). Dur: 0.1429s -> 2 units
        song_rom[226] = {OCTAVE_LOW, NOTE_B,   4'd2}; // MIDI 59 (B3), Dur: 0.1429s

        // Msg 386: note_on note=60 (Abs Time: 48.8556s)
        // Msg 387: note_off note=60 (Abs Time: 48.9985s)
        // Note: MIDI 60 (C4). Dur: 0.1429s -> 2 units
        song_rom[227] = {OCTAVE_MID, NOTE_C,   4'd2}; // MIDI 60 (C4), Dur: 0.1429s

        // Msg 388: note_on note=64 (Abs Time: 48.9985s)
        // Msg 389: note_off note=64 (Abs Time: 49.1413s)
        // Note: MIDI 64 (E4). Dur: 0.1428s -> 2 units
        song_rom[228] = {OCTAVE_MID, NOTE_E,   4'd2}; // MIDI 64 (E4), Dur: 0.1428s

        // Msg 390: note_on note=62 (Abs Time: 49.1413s)
        // Msg 391: note_off note=62 (Abs Time: 49.4270s)
        // Note: MIDI 62 (D4). Dur: 0.2857s -> 4 units
        song_rom[229] = {OCTAVE_MID, NOTE_D,   4'd4}; // MIDI 62 (D4), Dur: 0.2857s

        // Msg 392: note_on note=55 (Abs Time: 49.4270s)
        // Msg 393: note_off note=55 (Abs Time: 49.7127s)
        // Note: MIDI 55 (G3). Dur: 0.2857s -> 4 units
        song_rom[230] = {OCTAVE_LOW, NOTE_G,   4'd4}; // MIDI 55 (G3), Dur: 0.2857s

        // Msg 394: note_on note=54 (Abs Time: 49.7127s)
        // Msg 395: note_off note=54 (Abs Time: 50.2842s)
        // Note: MIDI 54 (F#3). Dur: 0.5715s -> 8 units
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