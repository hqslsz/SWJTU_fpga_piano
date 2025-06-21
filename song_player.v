// 文件: song_player.v
// 歌曲播放器模块
module song_player #(
    parameter CLK_FREQ_HZ = 50_000_000, // 系统时钟频率
    parameter KEY_ID_BITS = 4,         // 用于表示音符ID (C, C#, D ... B, 共12个音符 + REST休止符)
    parameter OCTAVE_BITS = 2          // 用于表示低、中、高八度
) (
    input clk,                   // 时钟
    input rst_n,                 // 低电平有效复位
    input play_active_level,     // 高电平播放，低电平停止 (或播放完成自动停止)

    output reg [KEY_ID_BITS-1:0] song_key_id,     // 输出: 当前歌曲的音符ID
    output reg song_key_is_pressed,             // 输出: 当前歌曲音符是否按下 (非休止符)
    output reg song_octave_up_feed,             // 新增输出: 八度升高信号
    output reg song_octave_down_feed,           // 新增输出: 八度降低信号
    output reg is_song_playing                  // 输出: 歌曲是否正在播放的状态指示
);

    // --- 音符定义 (KEY_ID 1-12, 0为休止符) ---  <<-- 这些定义必须在模块内部
    localparam NOTE_C   = 4'd1; localparam NOTE_CS  = 4'd8;  // C, C#
    localparam NOTE_D   = 4'd2; localparam NOTE_DS  = 4'd9;  // D, D# (或 Eb)
    localparam NOTE_E   = 4'd3;                             // E
    localparam NOTE_F   = 4'd4; localparam NOTE_FS  = 4'd10; // F, F#
    localparam NOTE_G   = 4'd5; localparam NOTE_GS  = 4'd11; // G, G# (或 Ab)
    localparam NOTE_A   = 4'd6; localparam NOTE_AS  = 4'd12; // A, A# (或 Bb)
    localparam NOTE_B   = 4'd7;                             // B
    localparam REST     = 4'd0; // 休止符

    // --- 八度定义 ---
    localparam OCTAVE_LOW  = 2'b10; // 信号: 激活八度降低
    localparam OCTAVE_MID  = 2'b00; // 信号: 正常 (中央) 八度
    localparam OCTAVE_HIGH = 2'b01; // 信号: 激活八度升高

    // --- 时长和乐谱数据定义 ---
    localparam DURATION_BITS = 4;     // 用于表示时长单位的位数 (例如，最多16个单位)
    localparam SONG_DATA_WIDTH = OCTAVE_BITS + KEY_ID_BITS + DURATION_BITS; // ROM中每个条目的数据宽度

    // !!! 这个 SONG_LENGTH 是根据提供的MIDI数据推导出来的 !!!
    localparam SONG_LENGTH = 245; // 总事件数: 例如 174个音符 + 8个休止符 (这里是示例值)

    // --- 节拍和基础时长单位 ---
    // !!! 确保此值与你的MIDI转录所用的值匹配 !!!
    localparam BASIC_NOTE_DURATION_MS = 70; // 用于转换的基础音符时长 (毫秒)
    localparam BASIC_NOTE_DURATION_CYCLES = (BASIC_NOTE_DURATION_MS * (CLK_FREQ_HZ / 1000)); // 基础时长对应的时钟周期数
    localparam MAX_DURATION_UNITS_VAL = (1 << DURATION_BITS) - 1; // 最大时长单位值

    // --- 状态机定义 ---
    localparam S_IDLE   = 1'b0; // 空闲状态
    localparam S_PLAYING= 1'b1; // 播放状态

    // --- 内部寄存器声明 ---
    reg [SONG_DATA_WIDTH-1:0] song_rom [0:SONG_LENGTH-1]; // 歌曲ROM

    reg [$clog2(SONG_LENGTH)-1:0] current_note_index;       // 当前音符在ROM中的索引
    reg [$clog2(BASIC_NOTE_DURATION_CYCLES * MAX_DURATION_UNITS_VAL + 1)-1:0] note_duration_timer; // 音符时长计时器
    reg [DURATION_BITS-1:0] current_note_duration_units;    // 当前音符的持续时长单位
    reg [KEY_ID_BITS-1:0] current_note_id_from_rom;         // 从ROM读取的当前音符ID
    reg [OCTAVE_BITS-1:0] current_octave_code_from_rom;   // 从ROM读取的当前八度编码
    reg state;                                            // 当前状态 (S_IDLE 或 S_PLAYING)
    reg play_active_level_prev;                           // 上一个周期的播放键电平，用于检测上升沿


    // ########################################################################## //
    // #                                                                        # //
    // #    <<<<< 请将下面的整个 'initial begin ... end' 块替换掉           >>>>>  # //
    // #    <<<<< 替换为你转录好的包含 song_rom 数据的块                     >>>>>  # //
    // #                                                                        # //
    // ########################################################################## //
    initial begin
        // --- "Bad Apple!!" 转录的歌曲数据 (部分示例) ---
        // --- 新片段转录数据 (大约 79 BPM) ---
        // 此片段共154个条目。
        // 如果要追加，例如在 song_rom[345] 之后，这些将从 song_rom[346] 开始。
        // 新的 SONG_LENGTH 将是 346 + 154 = 500。


    song_rom[  0]  = { OCTAVE_MID  , REST      , 4'd11 }; // Initial Rest, Dur: 0.7595s
    song_rom[  1]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2152s
    song_rom[  2]  = { OCTAVE_HIGH , NOTE_CS   , 4'd2 }; // MIDI 73 (C#5), Dur: 0.1424s
    song_rom[  3]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3592s
    song_rom[  4]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2168s
    song_rom[  5]  = { OCTAVE_MID  , NOTE_GS   , 4'd7 }; // MIDI 68 (G#4), Dur: 0.5032s
    song_rom[  6]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3576s
    song_rom[  7]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[  8]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2152s
    song_rom[  9]  = { OCTAVE_MID  , NOTE_DS   , 4'd7 }; // MIDI 63 (D#3), Dur: 0.5032s
    song_rom[ 10]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3576s
    song_rom[ 11]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3592s
    song_rom[ 12]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2152s
    song_rom[ 13]  = { OCTAVE_LOW  , NOTE_B    , 4'd7 }; // MIDI 59 (B3), Dur: 0.5032s
    song_rom[ 14]  = { OCTAVE_MID  , NOTE_FS   , 4'd8 }; // MIDI 66 (F#4), Dur: 0.5316s
    song_rom[ 15]  = { OCTAVE_MID  , NOTE_DS   , 4'd10 }; // MIDI 63 (D#3), Dur: 0.7199s
    song_rom[ 16]  = { OCTAVE_MID  , NOTE_CS   , 4'd6 }; // MIDI 61 (C#4), Dur: 0.4209s
    song_rom[ 17]  = { OCTAVE_MID  , NOTE_DS   , 4'd2 }; // MIDI 63 (D#3), Dur: 0.1424s
    song_rom[ 18]  = { OCTAVE_MID  , NOTE_E    , 4'd10 }; // MIDI 64 (E4), Dur: 0.7199s
    song_rom[ 19]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3608s
    song_rom[ 20]  = { OCTAVE_MID  , NOTE_AS   , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2152s
    song_rom[ 21]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1424s
    song_rom[ 22]  = { OCTAVE_MID  , NOTE_FS   , 4'd10 }; // MIDI 66 (F#4), Dur: 0.7199s
    song_rom[ 23]  = { OCTAVE_MID  , NOTE_E    , 4'd5 }; // MIDI 64 (E4), Dur: 0.3608s
    song_rom[ 24]  = { OCTAVE_MID  , NOTE_DS   , 4'd3 }; // MIDI 63 (D#3), Dur: 0.2152s
    song_rom[ 25]  = { OCTAVE_MID  , NOTE_E    , 4'd2 }; // MIDI 64 (E4), Dur: 0.1424s
    song_rom[ 26]  = { OCTAVE_MID  , NOTE_F    , 4'd8 }; // MIDI 65 (F4), Dur: 0.5744s
    song_rom[ 27]  = { OCTAVE_MID  , NOTE_F    , 4'd2 }; // MIDI 65 (F4), Dur: 0.1408s
    song_rom[ 28]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3608s
    song_rom[ 29]  = { OCTAVE_MID  , NOTE_AS   , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2152s
    song_rom[ 30]  = { OCTAVE_MID  , NOTE_GS   , 4'd2 }; // MIDI 68 (G#4), Dur: 0.1424s
    song_rom[ 31]  = { OCTAVE_MID  , NOTE_G    , 4'd10 }; // MIDI 67 (G4), Dur: 0.7199s
    song_rom[ 32]  = { OCTAVE_MID  , NOTE_B    , 4'd6 }; // MIDI 71 (B4), Dur: 0.4209s
    song_rom[ 33]  = { OCTAVE_HIGH , NOTE_CS   , 4'd2 }; // MIDI 73 (C#5), Dur: 0.1424s
    song_rom[ 34]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3592s
    song_rom[ 35]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2152s
    song_rom[ 36]  = { OCTAVE_MID  , NOTE_GS   , 4'd7 }; // MIDI 68 (G#4), Dur: 0.5047s
    song_rom[ 37]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3576s
    song_rom[ 38]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[ 39]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2152s
    song_rom[ 40]  = { OCTAVE_MID  , NOTE_DS   , 4'd7 }; // MIDI 63 (D#3), Dur: 0.5047s
    song_rom[ 41]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[ 42]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3592s
    song_rom[ 43]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2152s
    song_rom[ 44]  = { OCTAVE_LOW  , NOTE_B    , 4'd7 }; // MIDI 59 (B3), Dur: 0.5047s
    song_rom[ 45]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
    song_rom[ 46]  = { OCTAVE_MID  , NOTE_DS   , 4'd10 }; // MIDI 63 (D#3), Dur: 0.7199s
    song_rom[ 47]  = { OCTAVE_MID  , NOTE_CS   , 4'd6 }; // MIDI 61 (C#4), Dur: 0.4193s
    song_rom[ 48]  = { OCTAVE_MID  , NOTE_DS   , 4'd2 }; // MIDI 63 (D#3), Dur: 0.1424s
    song_rom[ 49]  = { OCTAVE_MID  , NOTE_E    , 4'd10 }; // MIDI 64 (E4), Dur: 0.7199s
    song_rom[ 50]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3608s
    song_rom[ 51]  = { OCTAVE_MID  , NOTE_E    , 4'd3 }; // MIDI 64 (E4), Dur: 0.2168s
    song_rom[ 52]  = { OCTAVE_MID  , NOTE_FS   , 4'd2 }; // MIDI 66 (F#4), Dur: 0.1424s
    song_rom[ 53]  = { OCTAVE_MID  , NOTE_DS   , 4'd5 }; // MIDI 63 (D#3), Dur: 0.3592s
    song_rom[ 54]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
    song_rom[ 55]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[ 56]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3592s
    song_rom[ 57]  = { OCTAVE_HIGH , NOTE_CS   , 4'd8 }; // MIDI 73 (C#5), Dur: 0.5744s
    song_rom[ 58]  = { OCTAVE_HIGH , NOTE_CS   , 4'd2 }; // MIDI 73 (C#5), Dur: 0.1424s
    song_rom[ 59]  = { OCTAVE_HIGH , NOTE_CS   , 4'd8 }; // MIDI 73 (C#5), Dur: 0.5728s
    song_rom[ 60]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1424s
    song_rom[ 61]  = { OCTAVE_MID  , NOTE_B    , 4'd15 }; // MIDI 71 (B4), Dur: 1.4415s
    song_rom[ 62]  = { OCTAVE_MID  , NOTE_B    , 4'd4 }; // MIDI 71 (B4), Dur: 0.2168s Rest, Dur: 2.7358s
    song_rom[ 63]  = { OCTAVE_MID  , REST      , 4'd15 }; // Rest, Dur: 2.7358s
    song_rom[ 64]  = { OCTAVE_HIGH , NOTE_CS   , 4'd2 }; // MIDI 73 (C#5), Dur: 0.1424s
    song_rom[ 65]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3592s
    song_rom[ 66]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2152s
    song_rom[ 67]  = { OCTAVE_MID  , NOTE_GS   , 4'd7 }; // MIDI 68 (G#4), Dur: 0.5047s
    song_rom[ 68]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3592s
    song_rom[ 69]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3576s
    song_rom[ 70]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2168s
    song_rom[ 71]  = { OCTAVE_MID  , NOTE_DS   , 4'd7 }; // MIDI 63 (D#3), Dur: 0.5047s
    song_rom[ 72]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[ 73]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3576s
    song_rom[ 74]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2168s
    song_rom[ 75]  = { OCTAVE_LOW  , NOTE_B    , 4'd7 }; // MIDI 59 (B3), Dur: 0.5032s
    song_rom[ 76]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
    song_rom[ 77]  = { OCTAVE_MID  , NOTE_DS   , 4'd13 }; // MIDI 63 (D#3), Dur: 0.9177s
    song_rom[ 78]  = { OCTAVE_MID  , NOTE_CS   , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2184s Rest, Dur: 0.2199s
    song_rom[ 79]  = { OCTAVE_MID  , REST      , 4'd3 }; // Rest, Dur: 0.2199s
    song_rom[ 80]  = { OCTAVE_MID  , NOTE_DS   , 4'd2 }; // MIDI 63 (D#3), Dur: 0.1424s
    song_rom[ 81]  = { OCTAVE_MID  , NOTE_E    , 4'd10 }; // MIDI 64 (E4), Dur: 0.7199s
    song_rom[ 82]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s Rest, Dur: 0.0380s
    song_rom[ 83]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0380s
    song_rom[ 84]  = { OCTAVE_MID  , NOTE_AS   , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2184s
    song_rom[ 85]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1424s
    song_rom[ 86]  = { OCTAVE_MID  , NOTE_FS   , 4'd10 }; // MIDI 66 (F#4), Dur: 0.7199s
    song_rom[ 87]  = { OCTAVE_MID  , NOTE_E    , 4'd5 }; // MIDI 64 (E4), Dur: 0.3592s Rest, Dur: 0.0380s
    song_rom[ 88]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0380s
    song_rom[ 89]  = { OCTAVE_MID  , NOTE_DS   , 4'd3 }; // MIDI 63 (D#3), Dur: 0.2184s
    song_rom[ 90]  = { OCTAVE_MID  , NOTE_E    , 4'd2 }; // MIDI 64 (E4), Dur: 0.1424s
    song_rom[ 91]  = { OCTAVE_MID  , NOTE_F    , 4'd10 }; // MIDI 65 (F4), Dur: 0.7199s Rest, Dur: 0.0380s
    song_rom[ 92]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0380s
    song_rom[ 93]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[ 94]  = { OCTAVE_MID  , NOTE_AS   , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2184s
    song_rom[ 95]  = { OCTAVE_MID  , NOTE_GS   , 4'd2 }; // MIDI 68 (G#4), Dur: 0.1424s
    song_rom[ 96]  = { OCTAVE_MID  , NOTE_G    , 4'd15 }; // MIDI 67 (G4), Dur: 1.0396s
    song_rom[ 97]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2184s Rest, Dur: 0.0981s
    song_rom[ 98]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0981s
    song_rom[ 99]  = { OCTAVE_HIGH , NOTE_CS   , 4'd2 }; // MIDI 73 (C#5), Dur: 0.1424s
    song_rom[100]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3576s
    song_rom[101]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2168s
    song_rom[102]  = { OCTAVE_MID  , NOTE_GS   , 4'd7 }; // MIDI 68 (G#4), Dur: 0.5032s
    song_rom[103]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3592s
    song_rom[104]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3576s
    song_rom[105]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2168s
    song_rom[106]  = { OCTAVE_MID  , NOTE_DS   , 4'd7 }; // MIDI 63 (D#3), Dur: 0.5032s
    song_rom[107]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[108]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3576s
    song_rom[109]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2168s
    song_rom[110]  = { OCTAVE_LOW  , NOTE_B    , 4'd7 }; // MIDI 59 (B3), Dur: 0.5032s
    song_rom[111]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
    song_rom[112]  = { OCTAVE_MID  , NOTE_DS   , 4'd15 }; // MIDI 63 (D#3), Dur: 1.1092s
    song_rom[113]  = { OCTAVE_MID  , NOTE_CS   , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2184s
    song_rom[114]  = { OCTAVE_MID  , NOTE_DS   , 4'd2 }; // MIDI 63 (D#3), Dur: 0.1408s
    song_rom[115]  = { OCTAVE_MID  , NOTE_E    , 4'd10 }; // MIDI 64 (E4), Dur: 0.7199s
    song_rom[116]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s Rest, Dur: 0.0380s
    song_rom[117]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0380s
    song_rom[118]  = { OCTAVE_MID  , NOTE_E    , 4'd3 }; // MIDI 64 (E4), Dur: 0.2184s
    song_rom[119]  = { OCTAVE_MID  , NOTE_FS   , 4'd2 }; // MIDI 66 (F#4), Dur: 0.1408s
    song_rom[120]  = { OCTAVE_MID  , NOTE_DS   , 4'd5 }; // MIDI 63 (D#3), Dur: 0.3576s
    song_rom[121]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3608s
    song_rom[122]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[123]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3592s
    song_rom[124]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2152s
    song_rom[125]  = { OCTAVE_HIGH , NOTE_CS   , 4'd7 }; // MIDI 73 (C#5), Dur: 0.5032s
    song_rom[126]  = { OCTAVE_HIGH , NOTE_CS   , 4'd8 }; // MIDI 73 (C#5), Dur: 0.5728s
    song_rom[127]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1408s
    song_rom[128]  = { OCTAVE_MID  , NOTE_B    , 4'd11 }; // MIDI 71 (B4), Dur: 1.1377s
    song_rom[129]  = { OCTAVE_MID  , NOTE_GS   , 4'd8 }; // MIDI 68 (G#4), Dur: 0.5712s Rest, Dur: 0.3813s
    song_rom[130]  = { OCTAVE_MID  , REST      , 4'd5 }; // Rest, Dur: 0.3813s
    song_rom[131]  = { OCTAVE_MID  , NOTE_AS   , 4'd2 }; // MIDI 70 (A#4), Dur: 0.1440s
    song_rom[132]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[133]  = { OCTAVE_MID  , NOTE_AS   , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2184s
    song_rom[134]  = { OCTAVE_MID  , NOTE_GS   , 4'd2 }; // MIDI 68 (G#4), Dur: 0.1408s
    song_rom[135]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
    song_rom[136]  = { OCTAVE_HIGH , NOTE_DS   , 4'd5 }; // MIDI 75 (D#5), Dur: 0.3592s
    song_rom[137]  = { OCTAVE_HIGH , NOTE_DS   , 4'd10 }; // MIDI 75 (D#5), Dur: 0.7294s
    song_rom[138]  = { OCTAVE_HIGH , NOTE_CS   , 4'd8 }; // MIDI 73 (C#5), Dur: 0.5649s
    song_rom[139]  = { OCTAVE_HIGH , NOTE_DS   , 4'd2 }; // MIDI 75 (D#5), Dur: 0.1440s Rest, Dur: 0.0411s
    song_rom[140]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0411s
    song_rom[141]  = { OCTAVE_HIGH , NOTE_E    , 4'd5 }; // MIDI 76 (E5), Dur: 0.3592s
    song_rom[142]  = { OCTAVE_HIGH , NOTE_DS   , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2184s
    song_rom[143]  = { OCTAVE_HIGH , NOTE_CS   , 4'd2 }; // MIDI 73 (C#5), Dur: 0.1408s
    song_rom[144]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[145]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3592s
    song_rom[146]  = { OCTAVE_MID  , NOTE_FS   , 4'd10 }; // MIDI 66 (F#4), Dur: 0.7199s
    song_rom[147]  = { OCTAVE_MID  , NOTE_E    , 4'd8 }; // MIDI 64 (E4), Dur: 0.5712s Rest, Dur: 0.0411s
    song_rom[148]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0411s
    song_rom[149]  = { OCTAVE_MID  , NOTE_FS   , 4'd2 }; // MIDI 66 (F#4), Dur: 0.1440s
    song_rom[150]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3592s
    song_rom[151]  = { OCTAVE_MID  , NOTE_FS   , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2168s
    song_rom[152]  = { OCTAVE_MID  , NOTE_E    , 4'd2 }; // MIDI 64 (E4), Dur: 0.1408s
    song_rom[153]  = { OCTAVE_MID  , NOTE_DS   , 4'd5 }; // MIDI 63 (D#3), Dur: 0.3608s
    song_rom[154]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[155]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[156]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3576s
    song_rom[157]  = { OCTAVE_MID  , NOTE_AS   , 4'd10 }; // MIDI 70 (A#4), Dur: 0.7199s
    song_rom[158]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3592s Rest, Dur: 0.0396s
    song_rom[159]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0396s
    song_rom[160]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3576s
    song_rom[161]  = { OCTAVE_MID  , NOTE_B    , 4'd10 }; // MIDI 71 (B4), Dur: 0.7199s Rest, Dur: 0.0396s
    song_rom[162]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0396s
    song_rom[163]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2184s
    song_rom[164]  = { OCTAVE_HIGH , NOTE_DS   , 4'd2 }; // MIDI 75 (D#5), Dur: 0.1424s
    song_rom[165]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2152s
    song_rom[166]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1408s
    song_rom[167]  = { OCTAVE_MID  , NOTE_GS   , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2168s
    song_rom[168]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[169]  = { OCTAVE_HIGH , NOTE_DS   , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2184s
    song_rom[170]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5032s
    song_rom[171]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2168s
    song_rom[172]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[173]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2184s
    song_rom[174]  = { OCTAVE_HIGH , NOTE_DS   , 4'd2 }; // MIDI 75 (D#5), Dur: 0.1424s
    song_rom[175]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2152s
    song_rom[176]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1408s
    song_rom[177]  = { OCTAVE_MID  , NOTE_GS   , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2168s
    song_rom[178]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[179]  = { OCTAVE_HIGH , NOTE_DS   , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2184s
    song_rom[180]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5032s
    song_rom[181]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2168s
    song_rom[182]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[183]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2184s
    song_rom[184]  = { OCTAVE_HIGH , NOTE_DS   , 4'd2 }; // MIDI 75 (D#5), Dur: 0.1424s
    song_rom[185]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2152s
    song_rom[186]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1408s
    song_rom[187]  = { OCTAVE_MID  , NOTE_GS   , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2168s
    song_rom[188]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[189]  = { OCTAVE_HIGH , NOTE_DS   , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2184s
    song_rom[190]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5032s
    song_rom[191]  = { OCTAVE_HIGH , NOTE_G    , 4'd3 }; // MIDI 80 (G5), Dur: 0.2168s
    song_rom[192]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5016s
    song_rom[193]  = { OCTAVE_HIGH , NOTE_FS   , 4'd3 }; // MIDI 78 (F#5), Dur: 0.2184s
    song_rom[194]  = { OCTAVE_HIGH , NOTE_AS   , 4'd8 }; // MIDI 83 (A#5), Dur: 0.5032s
    song_rom[195]  = { OCTAVE_HIGH , NOTE_A    , 4'd3 }; // MIDI 82 (A5), Dur: 0.1899s
    song_rom[196]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5047s Rest, Dur: 0.0649s
    song_rom[197]  = { OCTAVE_MID  , REST      , 4'd1 }; // Rest, Dur: 0.0649s
    song_rom[198]  = { OCTAVE_HIGH , NOTE_DS   , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2184s
    song_rom[199]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5032s
    song_rom[200]  = { OCTAVE_HIGH , NOTE_CS   , 4'd11 }; // MIDI 73 (C#5), Dur: 0.7579s
    song_rom[201]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2184s
    song_rom[202]  = { OCTAVE_HIGH , NOTE_DS   , 4'd2 }; // MIDI 75 (D#5), Dur: 0.1408s
    song_rom[203]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2152s
    song_rom[204]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1424s
    song_rom[205]  = { OCTAVE_MID  , NOTE_GS   , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2168s
    song_rom[206]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[207]  = { OCTAVE_HIGH , NOTE_DS   , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2184s
    song_rom[208]  = { OCTAVE_HIGH , NOTE_FS   , 4'd7 }; // MIDI 78 (F#5), Dur: 0.5032s
    song_rom[209]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2168s
    song_rom[210]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5016s
    song_rom[211]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2184s
    song_rom[212]  = { OCTAVE_MID  , NOTE_B    , 4'd2 }; // MIDI 71 (B4), Dur: 0.1408s
    song_rom[213]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2152s
    song_rom[214]  = { OCTAVE_HIGH , NOTE_DS   , 4'd2 }; // MIDI 75 (D#5), Dur: 0.1424s
    song_rom[215]  = { OCTAVE_HIGH , NOTE_E    , 4'd3 }; // MIDI 76 (E5), Dur: 0.2168s
    song_rom[216]  = { OCTAVE_HIGH , NOTE_DS   , 4'd7 }; // MIDI 75 (D#5), Dur: 0.5016s
    song_rom[217]  = { OCTAVE_HIGH , NOTE_CS   , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2184s
    song_rom[218]  = { OCTAVE_MID  , NOTE_AS   , 4'd7 }; // MIDI 70 (A#4), Dur: 0.5032s
    song_rom[219]  = { OCTAVE_MID  , NOTE_B    , 4'd13 }; // MIDI 71 (B4), Dur: 0.9288s
    song_rom[220]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2152s Rest, Dur: 0.2120s
    song_rom[221]  = { OCTAVE_MID  , REST      , 4'd3 }; // Rest, Dur: 0.2120s
    song_rom[222]  = { OCTAVE_MID  , NOTE_AS   , 4'd2 }; // MIDI 70 (A#4), Dur: 0.1424s
    song_rom[223]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3592s
    song_rom[224]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[225]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3592s
    song_rom[226]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3592s
    song_rom[227]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3766s
    song_rom[228]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
    song_rom[229]  = { OCTAVE_MID  , NOTE_DS   , 4'd3 }; // MIDI 63 (D#3), Dur: 0.2184s
    song_rom[230]  = { OCTAVE_MID  , NOTE_FS   , 4'd7 }; // MIDI 66 (F#4), Dur: 0.5032s
    song_rom[231]  = { OCTAVE_MID  , NOTE_GS   , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2168s
    song_rom[232]  = { OCTAVE_HIGH , NOTE_CS   , 4'd7 }; // MIDI 73 (C#5), Dur: 0.5032s
    song_rom[233]  = { OCTAVE_MID  , NOTE_AS   , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2184s
    song_rom[234]  = { OCTAVE_MID  , NOTE_B    , 4'd7 }; // MIDI 71 (B4), Dur: 0.5032s
    song_rom[235]  = { OCTAVE_MID  , NOTE_B    , 4'd13 }; // MIDI 71 (B4), Dur: 0.9177s
    song_rom[236]  = { OCTAVE_MID  , NOTE_B    , 4'd3 }; // MIDI 71 (B4), Dur: 0.2152s Rest, Dur: 0.2231s
    song_rom[237]  = { OCTAVE_MID  , REST      , 4'd3 }; // Rest, Dur: 0.2231s
    song_rom[238]  = { OCTAVE_MID  , NOTE_AS   , 4'd2 }; // MIDI 70 (A#4), Dur: 0.1424s
    song_rom[239]  = { OCTAVE_MID  , NOTE_GS   , 4'd5 }; // MIDI 68 (G#4), Dur: 0.3592s
    song_rom[240]  = { OCTAVE_MID  , NOTE_AS   , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3592s
    song_rom[241]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3576s
    song_rom[242]  = { OCTAVE_HIGH , NOTE_CS   , 4'd5 }; // MIDI 73 (C#5), Dur: 0.3608s
    song_rom[243]  = { OCTAVE_MID  , NOTE_B    , 4'd5 }; // MIDI 71 (B4), Dur: 0.3766s
    song_rom[244]  = { OCTAVE_MID  , NOTE_FS   , 4'd5 }; // MIDI 66 (F#4), Dur: 0.3592s
        // ...... (此处省略大量乐谱数据，请填入完整乐谱)
        // 初始化其他寄存器
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
    // ####################### 待替换块结束 ########################### //


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
                state <= S_IDLE;             // 返回空闲状态
                song_key_is_pressed <= 1'b0; // 静音
                song_octave_up_feed <= 1'b0;   // 停止时重置八度
                song_octave_down_feed <= 1'b0; // 停止时重置八度
                is_song_playing <= 1'b0;       // 更新状态
            end

            // 状态机逻辑
            case (state)
                S_IDLE: begin // 空闲状态
                    song_key_is_pressed <= 1'b0; // 在IDLE状态确保静音
                    song_octave_up_feed <= 1'b0;
                    song_octave_down_feed <= 1'b0;
                    is_song_playing <= 1'b0;       // 在IDLE状态确保播放状态为否

                    // 如果播放按键按下 (检测上升沿: 当前高电平，上一周期低电平)
                    if (play_active_level && !play_active_level_prev) begin
                        if (SONG_LENGTH > 0) begin    // 仅当有歌曲时才播放
                            state <= S_PLAYING;       // 进入播放状态
                            current_note_index <= 0;  // 从乐谱开头播放
                            // 读取第一个音符的数据
                            {current_octave_code_from_rom, current_note_id_from_rom, current_note_duration_units} = song_rom[0];

                            song_key_id <= current_note_id_from_rom; // 设置音符ID输出
                            song_key_is_pressed <= (current_note_id_from_rom != REST); // 如果不是休止符则按下
                            song_octave_up_feed <= (current_octave_code_from_rom == OCTAVE_HIGH); // 设置八度输出
                            song_octave_down_feed <= (current_octave_code_from_rom == OCTAVE_LOW);

                            note_duration_timer <= 0; // 重置音符时长计时器
                            is_song_playing <= 1'b1;  // 设置播放状态为是
                        end
                    end
                end // S_IDLE 结束

                S_PLAYING: begin // 播放状态
                    // 只有当播放按键仍然按下时才继续处理播放逻辑
                    if (play_active_level) begin
                        is_song_playing <= 1'b1; // 保持播放状态为是

                        if (current_note_duration_units == 0) begin // 如果当前音符时长为0 (理论上好的ROM不应发生)
                            // 防御性编程: 跳到下一个音符或在末尾停止
                            if (current_note_index < SONG_LENGTH - 1) begin // 如果不是最后一个音符
                                current_note_index <= current_note_index + 1;
                                {current_octave_code_from_rom, current_note_id_from_rom, current_note_duration_units} = song_rom[current_note_index + 1];
                                song_key_id <= current_note_id_from_rom;
                                song_key_is_pressed <= (current_note_id_from_rom != REST);
                                song_octave_up_feed <= (current_octave_code_from_rom == OCTAVE_HIGH);
                                song_octave_down_feed <= (current_octave_code_from_rom == OCTAVE_LOW);
                                note_duration_timer <= 0;
                            end else begin // 已经是最后一个音符，歌曲结束 (或最后一个音符时长无效)
                                state <= S_IDLE; // 返回空闲
                            end
                        end else if (note_duration_timer >= (BASIC_NOTE_DURATION_CYCLES * current_note_duration_units) - 1'b1 ) begin // 当前音符播放时长已到
                            // 切换到下一个音符
                            if (current_note_index < SONG_LENGTH - 1) begin // 如果不是最后一个音符
                                current_note_index <= current_note_index + 1; // 索引后移
                                // 读取下一个音符的数据 (为下一个周期准备)
                                {current_octave_code_from_rom, current_note_id_from_rom, current_note_duration_units} = song_rom[current_note_index + 1];

                                song_key_id <= current_note_id_from_rom; // 更新输出
                                song_key_is_pressed <= (current_note_id_from_rom != REST);
                                song_octave_up_feed <= (current_octave_code_from_rom == OCTAVE_HIGH);
                                song_octave_down_feed <= (current_octave_code_from_rom == OCTAVE_LOW);
                                note_duration_timer <= 0; // 为新音符重置计时器
                            end else begin // 已经是最后一个音符，歌曲结束
                                state <= S_IDLE; // 返回空闲
                                // 可选: 保持最后一个音符发声直到按钮释放，或在此处明确静音。
                                // 当前逻辑会进入IDLE，从而静音。
                            end
                        end else begin // 当前音符还未播完
                            note_duration_timer <= note_duration_timer + 1; // 继续计时
                            // 输出 (key_id, is_pressed, octave_feeds) 保持当前音符的状态
                        end
                    end else begin // 如果在S_PLAYING状态时play_active_level变为低
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