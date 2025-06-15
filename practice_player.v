// 文件: practice_player.v (重建的完整版本)
// 练习播放器模块，用于引导用户进行按键练习
module practice_player #(
    parameter NUM_DISPLAY_SEGMENTS = 6 // 用于练习提示的数码管段数 (例如SEG0-SEG5)
) (
    input clk,                          // 时钟
    input rst_n,                        // 低电平有效复位

    input practice_mode_active,         // 练习模式是否激活
    input [3:0] current_live_key_id,    // 当前用户按下的实时按键ID (0-12)
    input current_live_key_pressed,     // 用户是否有按键按下

    // 输出到数码管的数据 (每个3位，代表音符1-7或0为空白)
    output reg [2:0] display_out_seg0,  // 数码管段0的显示数据 (练习序列的最左边/下一个)
    output reg [2:0] display_out_seg1,
    output reg [2:0] display_out_seg2,
    output reg [2:0] display_out_seg3,
    output reg [2:0] display_out_seg4,
    output reg [2:0] display_out_seg5,

    output reg correct_note_played_event,    // 正确弹奏音符事件脉冲
    output reg wrong_note_played_event,      // 错误弹奏音符事件脉冲
    output reg practice_song_finished_event // 练习歌曲完成事件脉冲
);

// --- 参数 ---
localparam PRACTICE_SONG_LENGTH = 14; // 练习歌曲《小星星》的音符数量

// --- 函数 ---
// 获取练习歌曲中指定索引的音符ID (1-7代表C-G, 这里只用了1-6)
// 《小星星》简谱: 1 1 | 5 5 | 6 6 | 5 - | 4 4 | 3 3 | 2 2 | 1 - |
// 对应ID:        C C   G G   A A   G     F F   E E   D D   C
function [3:0] get_practice_song_note (input integer index);
    if (index >= PRACTICE_SONG_LENGTH || index < 0) begin // 索引越界检查
        get_practice_song_note = 4'd0; // 返回无效/休止符
    end else begin
        case (index) // 《小星星》的音符序列 (使用1-7的ID)
            0:  get_practice_song_note = 4'd1;  // C
            1:  get_practice_song_note = 4'd1;  // C
            2:  get_practice_song_note = 4'd5;  // G
            3:  get_practice_song_note = 4'd5;  // G
            4:  get_practice_song_note = 4'd6;  // A
            5:  get_practice_song_note = 4'd6;  // A
            6:  get_practice_song_note = 4'd5;  // G
            7:  get_practice_song_note = 4'd4;  // F (休止符通过不前进索引，或设定特定时长来处理，此处简化为连续音符)
            8:  get_practice_song_note = 4'd4;  // F
            9:  get_practice_song_note = 4'd3;  // E
            10: get_practice_song_note = 4'd3;  // E
            11: get_practice_song_note = 4'd2;  // D
            12: get_practice_song_note = 4'd2;  // D
            13: get_practice_song_note = 4'd1;  // C
            default: get_practice_song_note = 4'd0; // 默认无效
        endcase
    end
endfunction

// 将音乐按键ID (1-12) 转换为用于显示的基础音符ID (1-7 for C-B, 0 for blank/other)
// 练习模式通常只关注基础音符，不区分升降。
function [2:0] musical_to_display_id (input [3:0] musical_id);
    case (musical_id) // 只取C,D,E,F,G,A,B (ID 1-7)
        4'd1:  musical_to_display_id = 3'd1; // C
        4'd2:  musical_to_display_id = 3'd2; // D
        4'd3:  musical_to_display_id = 3'd3; // E
        4'd4:  musical_to_display_id = 3'd4; // F
        4'd5:  musical_to_display_id = 3'd5; // G
        4'd6:  musical_to_display_id = 3'd6; // A
        4'd7:  musical_to_display_id = 3'd7; // B
        // 半音键 (ID 8-12) 在此练习模式简化显示为其基础音符
        4'd8:  musical_to_display_id = 3'd1; // C# -> C
        4'd9:  musical_to_display_id = 3'd3; // Eb -> E (或 D# -> D, 取决于设计选择，此处是Eb->E)
        4'd10: musical_to_display_id = 3'd4; // F# -> F
        4'd11: musical_to_display_id = 3'd5; // G# -> G
        4'd12: musical_to_display_id = 3'd7; // Bb -> B
        default: musical_to_display_id = 3'd0; // 其他 (如休止符或无效ID) 显示为空白
    endcase
endfunction

// --- 内部寄存器 ---
reg [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] current_note_index_in_song; // 当前在练习歌曲中的音符索引
reg current_live_key_pressed_prev;                                  // 上一周期用户按键状态
reg [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] next_note_idx_calculated; // 移至模块级别声明 (计算得到的下一个音符索引)

// --- 信号线 ---
wire new_key_press_event; // 新按键按下事件 (上升沿)

// --- 任务 ---
// 更新数码管显示缓冲区 (显示从 base_song_idx_for_display 开始的 NUM_DISPLAY_SEGMENTS 个音符)
task update_display_buffer (input [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] base_song_idx_for_display);
    integer i; // 循环变量
    integer song_idx_to_show; // 要显示的歌曲音符索引
    reg [2:0] temp_display_buffer [NUM_DISPLAY_SEGMENTS-1:0]; // 临时显示缓冲
    begin // 任务体开始
        for (i = 0; i < NUM_DISPLAY_SEGMENTS; i = i + 1) begin // 循环开始
            song_idx_to_show = base_song_idx_for_display + i; // 计算要显示的音符在歌曲中的绝对索引
            if (song_idx_to_show < PRACTICE_SONG_LENGTH) begin // 如果索引在歌曲长度内
                // 将歌曲中的音乐ID转换为3位的显示ID
                temp_display_buffer[i] = musical_to_display_id(get_practice_song_note(song_idx_to_show));
            end else begin // 如果超出歌曲长度
                temp_display_buffer[i] = 3'd0; // 显示为空白
            end // if-else 结束
        end // for 循环结束
        // 将临时缓冲区的数赋给输出端口
        display_out_seg0 <= temp_display_buffer[0]; display_out_seg1 <= temp_display_buffer[1];
        display_out_seg2 <= temp_display_buffer[2]; display_out_seg3 <= temp_display_buffer[3];
        display_out_seg4 <= temp_display_buffer[4]; display_out_seg5 <= temp_display_buffer[5];
    end // 任务体结束
endtask

// --- 初始化块 ---
initial begin
    current_note_index_in_song = 0;
    correct_note_played_event = 1'b0; wrong_note_played_event = 1'b0;
    practice_song_finished_event = 1'b0;
    display_out_seg0 = 3'd0; display_out_seg1 = 3'd0; display_out_seg2 = 3'd0;
    display_out_seg3 = 3'd0; display_out_seg4 = 3'd0; display_out_seg5 = 3'd0;
    current_live_key_pressed_prev = 1'b0;
    next_note_idx_calculated = 0; // 初始化模块级寄存器
end

// --- 新按键按下事件的组合逻辑 ---
assign new_key_press_event = current_live_key_pressed && !current_live_key_pressed_prev; // 检测上升沿

// --- current_live_key_pressed_prev 的时序逻辑 ---
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_live_key_pressed_prev <= 1'b0;
    end else begin
        current_live_key_pressed_prev <= current_live_key_pressed; // 每个周期更新上一次的按键状态
    end
end

// --- 主要时序逻辑块 ---
always @(posedge clk or negedge rst_n) begin
    // 'next_note_idx_calculated' 是一个模块级寄存器, 在此块中使用前已赋值。
    if (!rst_n) begin // 复位处理
        current_note_index_in_song <= 0;
        correct_note_played_event <= 1'b0; wrong_note_played_event <= 1'b0;
        practice_song_finished_event <= 1'b0;
        update_display_buffer(0); // 复位时更新显示 (显示歌曲开头)
    end else begin
        // 默认将事件脉冲清零，它们只在一个周期内有效
        correct_note_played_event <= 1'b0;
        wrong_note_played_event <= 1'b0;
        // practice_song_finished_event 保持不清零直到退出练习模式或重新开始

        if (practice_mode_active) begin // 如果练习模式激活
            if (new_key_press_event && current_live_key_id != 4'd0) begin // 如果有新的有效按键按下
                if (current_note_index_in_song < PRACTICE_SONG_LENGTH) begin // 如果练习歌曲还未结束
                    // 将用户按下的键ID也转换为基础显示ID进行比较 (简化：假设练习只认基础音)
                    // 或者直接比较 current_live_key_id 与 get_practice_song_note 的原始输出
                    if (current_live_key_id == get_practice_song_note(current_note_index_in_song)) begin
                        // 用户弹对了当前期望的音符
                        correct_note_played_event <= 1'b1; // 发出正确事件脉冲
                        
                        next_note_idx_calculated = current_note_index_in_song + 1; // 计算下一个音符的索引

                        if (current_note_index_in_song == PRACTICE_SONG_LENGTH - 1) begin
                            // 这是歌曲的最后一个音符，并且弹对了
                            practice_song_finished_event <= 1'b1; // 发出歌曲完成事件
                            // 此时 next_note_idx_calculated会等于PRACTICE_SONG_LENGTH
                        end // end if (歌曲最后一个音符)
                        
                        current_note_index_in_song <= next_note_idx_calculated; // 更新当前音符索引到下一个
                        update_display_buffer(next_note_idx_calculated);      // 更新数码管显示，从下一个音符开始
                    end else begin // 用户弹错了音符
                        wrong_note_played_event <= 1'b1; // 发出错误事件脉冲
                        // 弹错时，当前音符索引不前进，显示也不变，等待用户弹对
                    end // end if (用户弹对/错)
                end // end if (练习歌曲未结束)
                // 如果 current_note_index_in_song >= PRACTICE_SONG_LENGTH，说明歌曲已完成，等待退出或重置
            end // end if (新按键按下)
        end else begin // 如果练习模式未激活 (例如刚退出或从未进入)
            if (current_note_index_in_song != 0) begin // 如果之前在练习，重置索引和显示
                 current_note_index_in_song <= 0;
                 update_display_buffer(0);
            end // end if (重置索引)
            if (practice_song_finished_event) begin // 如果之前完成了歌曲，清除完成标志
                practice_song_finished_event <= 1'b0;
            end // end if (清除完成标志)
        end // end if (练习模式激活/未激活)
    end // end if (!rst_n) else (主逻辑)
end // end always

endmodule