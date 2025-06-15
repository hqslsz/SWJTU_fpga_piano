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
    localparam SONG_LENGTH = 277; // 总事件数: 例如 174个音符 + 8个休止符 (这里是示例值)

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

        // 格式: {八度(2位), 音符ID(4位), 时长单位(4位)}
        song_rom[  0] = {OCTAVE_MID, REST,      4'd11}; // 初始休止符 时长: 0.7595s (示例计算)
        song_rom[  1] = {OCTAVE_MID, NOTE_B,    4'd3 }; // MIDI 71 (B4), 时长: 0.2152s (示例计算)
        song_rom[  2] = {OCTAVE_HIGH,NOTE_CS,   4'd2 }; // MIDI 73 (C#5), 时长: 0.1424s (示例计算)
        song_rom[  3] = {OCTAVE_HIGH,NOTE_DS,   4'd5 }; // MIDI 75 (D#5), 时长: 0.3591s (示例计算)
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