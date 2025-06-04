// File: song_player.v (再次修正 begin/end 结构，并添加扒谱注释)
module song_player #(
    parameter CLK_FREQ_HZ = 50_000_000,
    parameter KEY_ID_BITS = 4         // 与 fpga.v 中的 RECORDER_KEY_ID_BITS 保持一致
) (
    input clk,
    input rst_n,
    input play_active_level,          // 高电平播放，低电平停止

    output reg [KEY_ID_BITS-1:0] song_key_id,
    output reg song_key_is_pressed,
    output reg is_song_playing        // 歌曲正在播放的状态指示
);

    // --- 音符定义 ---
    // 这些 KEY_ID 基于你在 fpga.v 中定义的蜂鸣器频率计数
    // 1=C4, 2=D4, 3=E4, 4=F4, 5=G4, 6=A4, 7=B4
    // 半音: 8=C#4, 9=D#4/Eb4, 10=F#4, 11=G#4/Ab4, 12=A#4/Bb4
    // 你的国际歌是 bB 调 (1=bB)，所以:
    // 简谱 1 (Do) -> bB (A#) -> 使用 NOTE_AS4 (ID 12)
    // 简谱 2 (Re) -> C       -> 使用 NOTE_C4  (ID 1)
    // 简谱 3 (Mi) -> D       -> 使用 NOTE_D4  (ID 2)
    // 简谱 4 (Fa) -> Eb      -> 使用 NOTE_DS4 (ID 9)
    // 简谱 5 (So) -> F       -> 使用 NOTE_F4  (ID 4)
    // 简谱 6 (La) -> G       -> 使用 NOTE_G4  (ID 5)
    // 简谱 7 (Ti) -> A       -> 使用 NOTE_A4  (ID 6)
    // 简谱 #4(升Fa)-> E       -> 使用 NOTE_E4  (ID 3)
    // （高低音点暂时忽略，所有音符按 KEY_ID 对应的那个八度播放）
    localparam NOTE_C4  = 4'd1; localparam NOTE_CS4 = 4'd8;
    localparam NOTE_D4  = 4'd2; localparam NOTE_DS4 = 4'd9;
    localparam NOTE_E4  = 4'd3;
    localparam NOTE_F4  = 4'd4; localparam NOTE_FS4 = 4'd10;
    localparam NOTE_G4  = 4'd5; localparam NOTE_GS4 = 4'd11;
    localparam NOTE_A4  = 4'd6; localparam NOTE_AS4 = 4'd12; // A#/Bb
    localparam NOTE_B4  = 4'd7;
    localparam REST     = 4'd0; // 休止符

    // --- 时长和乐谱数据定义 ---
    localparam DURATION_BITS = 4;     // 用于表示时长单位的位数, 最大15个单位
                                      // 如果一个音符超过15个最小单位，需要增加此值
    localparam SONG_DATA_WIDTH = KEY_ID_BITS + DURATION_BITS; // 每个乐谱条目的总位数
    localparam SONG_LENGTH = 28;      // !!!重要!!! 你需要根据实际乐谱的音符总数修改这里
                                      // 我下面只写了部分示例音符，其余用休止符填充

    // --- 节拍和基础时长单位 ---
    // 简谱♩=98, 4/4拍。四分音符时长 = 60/98 ≈ 612ms.
    // 十六分音符时长 = 612ms / 4 ≈ 153ms.
    // 我们用十六分音符作为基础时长单位。
    localparam BASIC_NOTE_DURATION_MS = 100; // (毫秒) 一个时长单位 (Duration_Unit=1) 的长度，近似一个十六分音符
    localparam BASIC_NOTE_DURATION_CYCLES = (BASIC_NOTE_DURATION_MS * (CLK_FREQ_HZ / 1000));
    localparam MAX_DURATION_UNITS_VAL = (1 << DURATION_BITS) - 1; // DURATION_BITS能表示的最大单位数

    // --- 状态机定义 ---
    localparam S_IDLE   = 1'b0;
    localparam S_PLAYING= 1'b1;

    // --- 内部寄存器声明 ---
    reg [SONG_DATA_WIDTH-1:0] song_rom [0:SONG_LENGTH-1]; // 存储乐谱的ROM

    reg [$clog2(SONG_LENGTH)-1:0] current_note_index;     // 当前播放到乐谱的哪个音符
    reg [$clog2(BASIC_NOTE_DURATION_CYCLES * MAX_DURATION_UNITS_VAL + 1)-1:0] note_duration_timer; // 当前音符的持续时间计时器
    reg [DURATION_BITS-1:0] current_note_duration_units;  // 当前音符需要持续多少个时长单位
    reg [KEY_ID_BITS-1:0] current_note_id_from_rom;     // 从ROM中读取的当前音符的KEY_ID
    reg state;                                            // 状态机当前状态
    reg play_active_level_prev;                           // 前一个时钟周期的播放按键电平

    // --- 乐谱数据定义 ---
    // ... (NOTE_C4, NOTE_D4 etc. 定义不变) ...
    // ... (DURATION_BITS, SONG_DATA_WIDTH 定义不变) ...

    // --- 初始化 ---
    initial begin
        // --- 乐谱数据填充 (song_rom) ---
        // 歌曲: 小星星 (C调)
        // 格式: {时长单位 (DURATION_BITS位), 音符KEY_ID (KEY_ID_BITS位)}
        // 时长单位: 1 = 四分音符, 2 = 二分音符

        // 1 1 5 5 | (Do Do So So)
        song_rom[0]  = {4'd1, NOTE_C4}; // Do
        song_rom[1]  = {4'd1, NOTE_C4}; // Do
        song_rom[2]  = {4'd1, NOTE_G4}; // So
        song_rom[3]  = {4'd1, NOTE_G4}; // So
        // 6 6 5 - | (La La So-)
        song_rom[4]  = {4'd1, NOTE_A4}; // La
        song_rom[5]  = {4'd1, NOTE_A4}; // La
        song_rom[6]  = {4'd2, NOTE_G4}; // So (二分音符)
        // 4 4 3 3 | (Fa Fa Mi Mi)
        song_rom[7]  = {4'd1, NOTE_F4}; // Fa
        song_rom[8]  = {4'd1, NOTE_F4}; // Fa
        song_rom[9]  = {4'd1, NOTE_E4}; // Mi
        song_rom[10] = {4'd1, NOTE_E4}; // Mi
        // 2 2 1 - | (Re Re Do-)
        song_rom[11] = {4'd1, NOTE_D4}; // Re
        song_rom[12] = {4'd1, NOTE_D4}; // Re
        song_rom[13] = {4'd2, NOTE_C4}; // Do (二分音符)

        // 5 5 4 4 | (So So Fa Fa)
        song_rom[14] = {4'd1, NOTE_G4}; // So
        song_rom[15] = {4'd1, NOTE_G4}; // So
        song_rom[16] = {4'd1, NOTE_F4}; // Fa
        song_rom[17] = {4'd1, NOTE_F4}; // Fa
        // 3 3 2 - | (Mi Mi Re-)
        song_rom[18] = {4'd1, NOTE_E4}; // Mi
        song_rom[19] = {4'd1, NOTE_E4}; // Mi
        song_rom[20] = {4'd2, NOTE_D4}; // Re (二分音符)
        // (重复前面四句中的两句)
        // 5 5 4 4 | (So So Fa Fa)
        // song_rom[21] = {4'd1, NOTE_G4}; // So
        // song_rom[22] = {4'd1, NOTE_G4}; // So
        // song_rom[23] = {4'd1, NOTE_F4}; // Fa
        // song_rom[24] = {4'd1, NOTE_F4}; // Fa
        // 3 3 2 - | (Mi Mi Re-)
        // song_rom[25] = {4'd1, NOTE_E4}; // Mi
        // song_rom[26] = {4'd1, NOTE_E4}; // Mi
        // song_rom[27] = {4'd2, NOTE_D4}; // Re (二分音符)
        // (或者直接重复第一段)
        // 1 1 5 5 | (Do Do So So)
        song_rom[21]  = {4'd1, NOTE_C4}; // Do
        song_rom[22]  = {4'd1, NOTE_C4}; // Do
        song_rom[23]  = {4'd1, NOTE_G4}; // So
        song_rom[24]  = {4'd1, NOTE_G4}; // So
        // 6 6 5 - | (La La So-)
        song_rom[25]  = {4'd1, NOTE_A4}; // La
        song_rom[26]  = {4'd1, NOTE_A4}; // La
        song_rom[27]  = {4'd2, NOTE_G4}; // So (二分音符)
        // 4 4 3 3 | (Fa Fa Mi Mi) - 这句通常不重复，直接到 221-
        // 2 2 1 - | (Re Re Do-) - 这句也不重复

        // 歌曲结束，或者用一个长休止符填充。
        // 如果 SONG_LENGTH 是28，上面已经填满了。


        // 初始化输出和内部状态寄存器 (这部分代码不变)
        song_key_id = {KEY_ID_BITS{1'b0}};
        song_key_is_pressed = 1'b0;
        is_song_playing = 1'b0;
        state = S_IDLE;
        current_note_index = 0;
        note_duration_timer = 0;
        current_note_duration_units = 0;
        current_note_id_from_rom = {KEY_ID_BITS{1'b0}};
        play_active_level_prev = 1'b0;
    end

    // --- 主要状态机和逻辑 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位状态
            song_key_id <= {KEY_ID_BITS{1'b0}};
            song_key_is_pressed <= 1'b0;
            is_song_playing <= 1'b0;
            state <= S_IDLE;
            current_note_index <= 0;
            note_duration_timer <= 0;
            current_note_duration_units <= 0;
            current_note_id_from_rom <= {KEY_ID_BITS{1'b0}};
            play_active_level_prev <= 1'b0;
        end else begin
            play_active_level_prev <= play_active_level; // 存储当前按键电平，用于下一周期检测边沿

            // 首要停止条件: 如果播放按键变为低电平且当前正在播放，则立即停止
            if (!play_active_level && state == S_PLAYING) begin
                state <= S_IDLE;
                song_key_is_pressed <= 1'b0; // 静音
                is_song_playing <= 1'b0;   // 更新状态
            end

            // 状态机逻辑
            case (state)
                S_IDLE: begin
                    song_key_is_pressed <= 1'b0; // 在IDLE状态确保静音
                    is_song_playing <= 1'b0;   // 在IDLE状态确保播放状态为否

                    // 如果播放按键按下 (检测上升沿)
                    if (play_active_level && !play_active_level_prev) begin
                        state <= S_PLAYING;     // 进入播放状态
                        current_note_index <= 0;  // 从乐谱开头播放
                        {current_note_duration_units, current_note_id_from_rom} = song_rom[0]; // 读取第一个音符
                        song_key_id <= current_note_id_from_rom;
                        song_key_is_pressed <= (current_note_id_from_rom != REST); // 如果不是休止符则发声
                        note_duration_timer <= 0; // 重置音符时长计时器
                        is_song_playing <= 1'b1;  // 设置播放状态为是
                    end
                end // S_IDLE 结束

                S_PLAYING: begin
                    // 只有当播放按键仍然按下时才继续处理播放逻辑
                    if (play_active_level) begin
                        is_song_playing <= 1'b1; // 保持播放状态为是

                        // 处理音符播放和切换
                        if (current_note_duration_units == 0) begin // 如果当前音符时长单位为0 (理论上不应出现，除非乐谱错误)
                            // 跳到下一个音符
                            if (current_note_index < SONG_LENGTH - 1) begin
                                current_note_index <= current_note_index + 1;
                                {current_note_duration_units, current_note_id_from_rom} = song_rom[current_note_index + 1];
                                song_key_id <= current_note_id_from_rom;
                                song_key_is_pressed <= (current_note_id_from_rom != REST);
                                note_duration_timer <= 0;
                            end else begin // 已经是最后一个音符，歌曲结束
                                state <= S_IDLE;
                            end
                        end else if (note_duration_timer >= (BASIC_NOTE_DURATION_CYCLES * current_note_duration_units) - 1'b1 ) begin // 当前音符播放时长已到
                            // 切换到下一个音符
                            if (current_note_index < SONG_LENGTH - 1) begin
                                current_note_index <= current_note_index + 1;
                                {current_note_duration_units, current_note_id_from_rom} = song_rom[current_note_index + 1];
                                song_key_id <= current_note_id_from_rom;
                                song_key_is_pressed <= (current_note_id_from_rom != REST);
                                note_duration_timer <= 0;
                            end else begin // 已经是最后一个音符，歌曲结束
                                state <= S_IDLE;
                            end
                        end else begin // 当前音符还未播完
                            note_duration_timer <= note_duration_timer + 1; // 继续计时
                        end
                    end else begin
                        // 如果在S_PLAYING状态时play_active_level变为低 (此分支主要应对在进入S_PLAYING的同一周期按键就抬起的情况，或作为安全措施)
                        state <= S_IDLE;          // 强制回到IDLE
                        song_key_is_pressed <= 1'b0; // 静音
                        is_song_playing <= 1'b0;    // 更新状态
                    end
                end // S_PLAYING 结束

                default: state <= S_IDLE; // 意外状态则回到IDLE
            endcase // case(state) 结束
        end // else (if !rst_n) 结束
    end // always 结束
endmodule // 模块结束