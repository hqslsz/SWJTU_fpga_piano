# fpga
SWJTU数电课设电子琴

## 核心代码
### 1.fpga.v
```verilog
// 文件: fpga.v (已修改以集成练习模式)
// FPGA电子琴顶层模块，包含录音、半音、歌曲播放和练习模式

module fpga (
    // 时钟和复位
    input clk_50mhz,             // 系统时钟 (PIN_90)
    input sw0_physical_reset,    // 物理复位按钮 (Key0/SW0, PIN_24, 高电平按下有效)
    // 音符按键
    input [6:0] note_keys_physical_in, // Key1-Key7 (C,D,E,F,G,A,B)
    // 半音按键 (Key8-Key12)
    input key8_sharp1_raw,         // 1# (C#)
    input key9_flat3_raw,          // 3b (Eb)
    input key10_sharp4_raw,        // 4# (F#) 
    input key11_sharp5_raw,        // 5# (G#)
    input key12_flat7_raw,         // 7b (Bb) 
    // 控制按键
    input sw15_octave_up_raw,    // 八度增加键
    input sw13_octave_down_raw,  // 八度降低键
    input sw16_record_raw,       // 录音键
    input sw17_playback_raw,     // 播放键
    input key14_play_song_raw,   // 播放歌曲键
    // 输出
    output reg buzzer_out,       // 蜂鸣器输出
    // 7段数码管输出
    output seven_seg_a, output seven_seg_b, output seven_seg_c, output seven_seg_d,
    output seven_seg_e, output seven_seg_f, output seven_seg_g, output seven_seg_dp,
    output [7:0] seven_seg_digit_selects // 用于SEG0-SEG7位选
);
// --- 内部复位逻辑 ---
wire rst_n_internal;
assign rst_n_internal = ~sw0_physical_reset; // 物理按键sw0按下为高电平，产生低电平有效复位
// --- 消抖参数 ---
localparam DEBOUNCE_TIME_MS = 20; // 消抖时间（毫秒）
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000); // 消抖所需时钟周期数 (50MHz时钟)
// --- 合并所有音乐按键输入 ---
localparam NUM_BASE_KEYS = 7;           // 基本音符按键数量 (C,D,E,F,G,A,B)
localparam NUM_SEMITONE_KEYS = 5;       // 半音按键数量 (C#,Eb,F#,G#,Bb)
localparam NUM_TOTAL_MUSICAL_KEYS = NUM_BASE_KEYS + NUM_SEMITONE_KEYS; // 总音乐按键数 (12)
localparam RECORDER_KEY_ID_BITS = 4;    // 录音模块中按键ID位数 (12个音符 + 休止符0，需要4位表示0-12)
localparam RECORDER_OCTAVE_BITS = 2;    // 录音模块中八度信息位数
wire [NUM_TOTAL_MUSICAL_KEYS-1:0] all_musical_keys_raw; // 原始音乐按键输入总线
assign all_musical_keys_raw[0] = note_keys_physical_in[0]; // C -> 扫描器中的ID 1
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
// --- 键盘扫描器实例化 ---
wire [RECORDER_KEY_ID_BITS-1:0] current_active_key_id_internal; // 从扫描器输出的当前活动按键ID (0表示无, 1-12表示按键)
wire       current_key_is_pressed_flag_internal; // 当前是否有按键按下的标志
keyboard_scanner #( .NUM_KEYS(NUM_TOTAL_MUSICAL_KEYS), .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS) )
keyboard_scanner_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), .keys_in_raw(all_musical_keys_raw),
    .active_key_id(current_active_key_id_internal), .key_is_pressed(current_key_is_pressed_flag_internal)
);
// --- 控制按键的消抖器 ---
wire sw15_octave_up_debounced_internal, sw13_octave_down_debounced_internal; // 八度增/减 (消抖后)
wire sw16_record_debounced_internal, sw17_playback_debounced_internal, key14_play_song_debounced_internal; // 录音/播放/歌曲播放 (消抖后)
wire sw17_playback_pulse_internal; // 播放键的单脉冲信号
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) octave_up_deb_inst (.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw15_octave_up_raw),   .key_out_debounced(sw15_octave_up_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) octave_down_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw13_octave_down_raw), .key_out_debounced(sw13_octave_down_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) record_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw16_record_raw),       .key_out_debounced(sw16_record_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) playback_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(sw17_playback_raw),     .key_out_debounced(sw17_playback_debounced_internal));
debouncer #( .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC) ) play_song_deb_inst(.clk(clk_50mhz), .rst_n(rst_n_internal), .key_in_raw(key14_play_song_raw),   .key_out_debounced(key14_play_song_debounced_internal));
// 为播放键(sw17)生成上升沿脉冲
reg sw17_playback_debounced_prev; initial sw17_playback_debounced_prev = 1'b0;
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) sw17_playback_debounced_prev <= 1'b0; else sw17_playback_debounced_prev <= sw17_playback_debounced_internal; end
assign sw17_playback_pulse_internal = sw17_playback_debounced_internal & ~sw17_playback_debounced_prev;
// --- 钢琴录音机实例化 ---
wire [RECORDER_KEY_ID_BITS-1:0] playback_key_id_feed; // 回放时的按键ID
wire playback_key_is_pressed_feed;                    // 回放时按键是否按下
wire playback_octave_up_feed, playback_octave_down_feed; // 回放时的八度状态
wire is_recording_status, is_playing_status;          // 当前是否正在录音/播放的状态
piano_recorder #( .CLK_FREQ_HZ(50_000_000), .RECORD_INTERVAL_MS(20), .MAX_RECORD_SAMPLES(512), .KEY_ID_BITS(RECORDER_KEY_ID_BITS), .OCTAVE_BITS(RECORDER_OCTAVE_BITS) )
piano_recorder_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), 
    .record_active_level(sw16_record_debounced_internal),   // 录音键激活电平 (按住录音)
    .playback_start_pulse(sw17_playback_pulse_internal), // 播放开始脉冲
    .live_key_id(current_active_key_id_internal),           // 实时按键ID
    .live_key_is_pressed(current_key_is_pressed_flag_internal), // 实时按键是否按下
    .live_octave_up(sw15_octave_up_debounced_internal),     // 实时八度增加信号
    .live_octave_down(sw13_octave_down_debounced_internal), // 实时八度降低信号
    .playback_key_id(playback_key_id_feed),               // 输出: 回放按键ID
    .playback_key_is_pressed(playback_key_is_pressed_feed),// 输出: 回放按键是否按下
    .playback_octave_up(playback_octave_up_feed),        // 输出: 回放八度增加
    .playback_octave_down(playback_octave_down_feed),    // 输出: 回放八度降低
    .is_recording(is_recording_status),                   // 输出: 是否正在录音
    .is_playing(is_playing_status)                       // 输出: 是否正在回放
);
// --- 歌曲播放器实例化 ---
wire [RECORDER_KEY_ID_BITS-1:0] song_player_key_id_feed; // 歌曲播放时的按键ID
wire song_player_key_is_pressed_feed;                   // 歌曲播放时按键是否按下
wire song_player_octave_up_internal, song_player_octave_down_internal; // 歌曲播放时的八度状态
wire is_song_playing_status;                            // 当前是否正在播放歌曲的状态
song_player #( .CLK_FREQ_HZ(50_000_000), .KEY_ID_BITS(RECORDER_KEY_ID_BITS), .OCTAVE_BITS(RECORDER_OCTAVE_BITS) )
song_player_inst (
    .clk(clk_50mhz), .rst_n(rst_n_internal), 
    .play_active_level(key14_play_song_debounced_internal), // 歌曲播放键激活电平
    .song_key_id(song_player_key_id_feed),                  // 输出: 歌曲按键ID
    .song_key_is_pressed(song_player_key_is_pressed_feed),  // 输出: 歌曲按键是否按下
    .song_octave_up_feed(song_player_octave_up_internal),   // 输出: 歌曲八度增加
    .song_octave_down_feed(song_player_octave_down_internal),// 输出: 歌曲八度降低
    .is_song_playing(is_song_playing_status)                // 输出: 是否正在播放歌曲
);
// --- 模式序列器实例化---
// 用于检测特定按键序列以进入练习模式
wire practice_mode_trigger_pulse_internal; // 练习模式触发脉冲
mode_sequencer mode_sequencer_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .current_live_key_id(current_active_key_id_internal),       // 来自键盘扫描器的实时按键ID
    .current_live_key_pressed(current_key_is_pressed_flag_internal), // 来自键盘扫描器的实时按键按下标志
    .practice_mode_active_pulse(practice_mode_trigger_pulse_internal) // 输出: 练习模式激活脉冲
);
// --- 练习模式使能逻辑---
reg practice_mode_enabled_reg; initial practice_mode_enabled_reg = 1'b0; // 练习模式使能寄存器
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if (!rst_n_internal) begin
        practice_mode_enabled_reg <= 1'b0;
    end else begin
        if (practice_mode_trigger_pulse_internal) begin
            practice_mode_enabled_reg <= ~practice_mode_enabled_reg; // 触发脉冲到来时，翻转练习模式状态
        end
    end
end

// --- 练习播放器实例化---
localparam NUM_PRACTICE_DISPLAY_SEGMENTS = 6; // 练习模式用于显示的数码管段数
wire [2:0] practice_data_s0; // 用于从 practice_player 输出的 display_out_seg0
wire [2:0] practice_data_s1;
wire [2:0] practice_data_s2;
wire [2:0] practice_data_s3;
wire [2:0] practice_data_s4;
wire [2:0] practice_data_s5; // 练习显示数据数组
wire practice_correct_event;   // 练习时弹对音符事件
wire practice_wrong_event;     // 练习时弹错音符事件
wire practice_finished_event;  // 练习歌曲完成事件

// fpga.v 中 practice_player_inst 实例化
practice_player #( .NUM_DISPLAY_SEGMENTS(NUM_PRACTICE_DISPLAY_SEGMENTS) ) practice_player_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .practice_mode_active(practice_mode_enabled_reg),        // 练习模式是否激活
    .current_live_key_id(current_active_key_id_internal),     // 实时按键ID
    .current_live_key_pressed(current_key_is_pressed_flag_internal), // 实时按键是否按下
    .display_out_seg0(practice_data_s0),
    .display_out_seg1(practice_data_s1),
    .display_out_seg2(practice_data_s2),
    .display_out_seg3(practice_data_s3),
    .display_out_seg4(practice_data_s4),
    .display_out_seg5(practice_data_s5),
    .correct_note_played_event(practice_correct_event),    // 输出: 弹对音符事件
    .wrong_note_played_event(practice_wrong_event),        // 输出: 弹错音符事件
    .practice_song_finished_event(practice_finished_event) // 输出: 练习歌曲完成事件
);
// ---声音/显示源多路选择器---
wire [RECORDER_KEY_ID_BITS-1:0] final_key_id_for_sound_and_display; // 最终用于声音和显示的按键ID
wire final_key_is_pressed_for_sound_and_display;                    //最终用于声音和显示的按键按下标志
wire final_octave_up_for_sound_and_display, final_octave_down_for_sound_and_display; // 最终用于声音和显示的八度状态
// 优先级顺序:
// 1. 练习模式: 声音来自实时按键
// 2. 歌曲播放器
// 3. 录音回放
// 4. 实时按键 (普通模式)
assign final_key_id_for_sound_and_display =
    (practice_mode_enabled_reg) ? current_active_key_id_internal : 
    (is_song_playing_status ? song_player_key_id_feed :
    (is_playing_status ? playback_key_id_feed : current_active_key_id_internal));

assign final_key_is_pressed_for_sound_and_display =
    (practice_mode_enabled_reg) ? current_key_is_pressed_flag_internal :
    (is_song_playing_status ? song_player_key_is_pressed_feed :
    (is_playing_status ? playback_key_is_pressed_feed : current_key_is_pressed_flag_internal));
// 练习模式声音的八度也将来自全局八度按钮
assign final_octave_up_for_sound_and_display =
    (is_song_playing_status && !practice_mode_enabled_reg) ? song_player_octave_up_internal : // 歌曲八度仅在非练习模式下有效
    ((is_playing_status && !practice_mode_enabled_reg) ? playback_octave_up_feed :            // 回放八度仅在非练习模式下有效
    sw15_octave_up_debounced_internal);                                                       // 实时/练习模式八度

assign final_octave_down_for_sound_and_display =
    (is_song_playing_status && !practice_mode_enabled_reg) ? song_player_octave_down_internal :
    ((is_playing_status && !practice_mode_enabled_reg) ? playback_octave_down_feed :
    sw13_octave_down_debounced_internal);
// --- 蜂鸣器频率生成 ---
localparam CNT_C4=17'd95566, CNT_CS4=17'd90194, CNT_D4=17'd85135, CNT_DS4=17'd80346, CNT_E4=17'd75830;
localparam CNT_F4=17'd71569, CNT_FS4=17'd67569, CNT_G4=17'd63775, CNT_GS4=17'd60197, CNT_A4=17'd56817;
localparam CNT_AS4=17'd53627,CNT_B4=17'd50619;
reg [17:0] buzzer_counter_reg;      // 蜂鸣器PWM计数器
reg [17:0] base_note_target_count;  // 基础音符的目标计数值 (C4八度)
reg [17:0] final_target_count_max;  // 考虑八度后的最终目标计数值
// 声音生成的组合逻辑
always @(*) begin
    case (final_key_id_for_sound_and_display) // 使用多路选择后的按键ID
        4'd1:  base_note_target_count = CNT_C4;  4'd8:  base_note_target_count = CNT_CS4; // C, C#
        4'd2:  base_note_target_count = CNT_D4;  4'd9:  base_note_target_count = CNT_DS4; // D, D#(Eb)
        4'd3:  base_note_target_count = CNT_E4;  // 你使用的ID 9 是 D#(Eb), 这里没有单独的Eb计数器 (E)
        4'd4:  base_note_target_count = CNT_F4;  4'd10: base_note_target_count = CNT_FS4; // F, F#
        4'd5:  base_note_target_count = CNT_G4;  4'd11: base_note_target_count = CNT_GS4; // G, G#(Ab)
        4'd6:  base_note_target_count = CNT_A4;  4'd12: base_note_target_count = CNT_AS4; // A, A#(Bb)
        4'd7:  base_note_target_count = CNT_B4;                                       // B
        default: base_note_target_count = 18'h3FFFF; // 静音 (一个较大的计数值，使频率非常低)
    endcase

    if (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display) begin // 八度升高
        final_target_count_max = (base_note_target_count + 1) / 2 - 1; // 频率加倍 -> 计数值减半
    end else if (!final_octave_up_for_sound_and_display && final_octave_down_for_sound_and_display) begin // 八度降低
        final_target_count_max = (base_note_target_count + 1) * 2 - 1; // 频率减半 -> 计数值加倍
    end else begin // 正常八度
        final_target_count_max = base_note_target_count;
    end
end
initial begin buzzer_out = 1'b0; buzzer_counter_reg = 18'd0; end
always @(posedge clk_50mhz or negedge rst_n_internal) begin
    if(!rst_n_internal) begin
        buzzer_counter_reg <= 18'd0; buzzer_out <= 1'b0;
    end else if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin // 有效按键按下
        if (buzzer_counter_reg >= final_target_count_max) begin // 达到半周期
            buzzer_counter_reg <= 18'd0;    // 重置计数器
            buzzer_out <= ~buzzer_out;      // 翻转蜂鸣器输出
        end else begin
            buzzer_counter_reg <= buzzer_counter_reg + 1'b1; // 计数器加1
        end
    end else if (practice_correct_event) begin //正确提示音 (短促高音)
    end else if (practice_wrong_event) begin   //错误提示音 (短促低音)
    end else begin // 无按键，无反馈
        buzzer_counter_reg <= 18'd0; buzzer_out <= 1'b0; // 静音
    end
end
// --- 为显示模块准备数据---
reg [2:0] base_note_id_for_buffer_and_suffix; // 用于滚动缓冲和后缀显示的基础音符ID (1-7 for C-B)
reg [1:0] semitone_type_for_suffix;           // 用于后缀显示的半音类型 (00:无, 01:#, 10:b)
reg       current_note_is_valid_for_display;  // 当前音符是否有效，用于显示
// 这个always块主要为滚动显示(非练习模式)和SEG0上的半音后缀准备数据。
always @(*) begin
    base_note_id_for_buffer_and_suffix = 3'd0; // 默认为空
    semitone_type_for_suffix = 2'b00;          // 默认为无半音
    current_note_is_valid_for_display = 1'b0;  // 默认音符无效
    if (final_key_is_pressed_for_sound_and_display && final_key_id_for_sound_and_display != 4'd0) begin
        current_note_is_valid_for_display = 1'b1;
        case (final_key_id_for_sound_and_display) // 根据最终按键ID确定基础音符和半音类型
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

// --- 为触发滚动缓冲生成新有效音符的脉冲 ---
reg  final_key_is_pressed_for_sound_and_display_prev;      // 上一个周期的按键按下状态
reg  [RECORDER_KEY_ID_BITS-1:0] final_key_id_for_sound_and_display_prev; // 上一个周期的按键ID
wire new_note_to_scroll_pulse;                               // 新音符送去滚动的脉冲

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
            final_key_id_for_sound_and_display_prev <= {RECORDER_KEY_ID_BITS{1'b0}}; // 无按键则清零
        end
    end
end

// 当新按键按下，或者按下的键发生变化时，产生一个脉冲 (且不在练习模式)
assign new_note_to_scroll_pulse =
    !practice_mode_enabled_reg && // 仅在非练习模式下滚动
    (
        (final_key_is_pressed_for_sound_and_display && !final_key_is_pressed_for_sound_and_display_prev) || // 新按下
        (final_key_is_pressed_for_sound_and_display && (final_key_id_for_sound_and_display != final_key_id_for_sound_and_display_prev)) // 按键变化
    ) && current_note_is_valid_for_display; // 且当前音符有效

// --- 实例化滚动显示缓冲模块 ---
wire [2:0] scroll_data_seg1_feed; wire [2:0] scroll_data_seg2_feed; // 送给数码管SEG1-SEG6的数据
wire [2:0] scroll_data_seg3_feed; wire [2:0] scroll_data_seg4_feed;
wire [2:0] scroll_data_seg5_feed; wire [2:0] scroll_data_seg6_feed;

scrolling_display_buffer scroller_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    .new_note_valid_pulse(new_note_to_scroll_pulse),                // 新音符有效脉冲
    .current_base_note_id_in(base_note_id_for_buffer_and_suffix), // 当前基础音符ID输入
    .display_data_seg1(scroll_data_seg1_feed), // 输出: SEG1显示数据
    .display_data_seg2(scroll_data_seg2_feed), // 输出: SEG2显示数据
    .display_data_seg3(scroll_data_seg3_feed), // 输出: SEG3显示数据
    .display_data_seg4(scroll_data_seg4_feed), // 输出: SEG4显示数据
    .display_data_seg5(scroll_data_seg5_feed), // 输出: SEG5显示数据
    .display_data_seg6(scroll_data_seg6_feed)  // 输出: SEG6显示数据
);

// --- 送给 seven_segment_controller 的最终数据线 (新增) ---
wire [2:0] final_to_sev_seg1_data; wire [2:0] final_to_sev_seg2_data;
wire [2:0] final_to_sev_seg3_data; wire [2:0] final_to_sev_seg4_data;
wire [2:0] final_to_sev_seg5_data; wire [2:0] final_to_sev_seg6_data;

// --- SEG1-SEG6 显示数据多路选择 (新增) ---
// 根据是否在练习模式，选择不同的数据显示源
assign final_to_sev_seg1_data = practice_mode_enabled_reg ? practice_data_s0 : scroll_data_seg1_feed;
assign final_to_sev_seg2_data = practice_mode_enabled_reg ? practice_data_s1 : scroll_data_seg2_feed;
assign final_to_sev_seg3_data = practice_mode_enabled_reg ? practice_data_s2 : scroll_data_seg3_feed;
assign final_to_sev_seg4_data = practice_mode_enabled_reg ? practice_data_s3 : scroll_data_seg4_feed;
assign final_to_sev_seg5_data = practice_mode_enabled_reg ? practice_data_s4 : scroll_data_seg5_feed;
assign final_to_sev_seg6_data = practice_mode_enabled_reg ? practice_data_s5 : scroll_data_seg6_feed;
// --- 实例化七段数码管控制器 (输入已修改) ---
seven_segment_controller seven_segment_display_inst (
    .clk(clk_50mhz),
    .rst_n(rst_n_internal),
    // SEG0 输入 (后缀 / 练习模式指示)
    // 已修改: 如果在练习模式, 显示 'P' (通过特定编码2'b11), 否则显示半音符号.
    .semitone_type_in(practice_mode_enabled_reg ? 2'b11 : semitone_type_for_suffix), // 2'b11 可作为控制器中 'P' 的编码
    .semitone_display_active_flag(practice_mode_enabled_reg ? 1'b1 : current_note_is_valid_for_display), // 练习模式常亮'P', 否则根据音符有效性
    // SEG1-SEG6 输入 (多路选择后的数据)
    .scrolled_note_seg1_in(final_to_sev_seg1_data),
    .scrolled_note_seg2_in(final_to_sev_seg2_data),
    .scrolled_note_seg3_in(final_to_sev_seg3_data),
    .scrolled_note_seg4_in(final_to_sev_seg4_data),
    .scrolled_note_seg5_in(final_to_sev_seg5_data),
    .scrolled_note_seg6_in(final_to_sev_seg6_data),
    // SEG7 输入 (八度 / 练习反馈)
    .octave_up_active(practice_mode_enabled_reg ? practice_correct_event : (final_octave_up_for_sound_and_display && !final_octave_down_for_sound_and_display)),
    .octave_down_active(practice_mode_enabled_reg ? practice_wrong_event : (final_octave_down_for_sound_and_display && !final_octave_up_for_sound_and_display)),

    // 七段数码管段选和位选输出
    .seg_a(seven_seg_a), .seg_b(seven_seg_b), .seg_c(seven_seg_c), .seg_d(seven_seg_d),
    .seg_e(seven_seg_e), .seg_f(seven_seg_f), .seg_g(seven_seg_g), .seg_dp(seven_seg_dp),
    .digit_selects(seven_seg_digit_selects)
);
endmodule
```
### 2.debouncer.v
```verilog
// 文件: debouncer.v
// 按键消抖模块
module debouncer #(
    parameter DEBOUNCE_CYCLES = 1000000 // 默认值，对应50MHz时钟下20ms
) (
    input clk,               // 时钟信号
    input rst_n,             // 低电平有效复位
    input key_in_raw,        // 原始物理按键输入 (高电平有效)
    output reg key_out_debounced // 消抖后的按键状态 (高电平有效)
);

// 对于 DEBOUNCE_CYCLES = 1,000,000, 计数器需要20位 (2^20 > 10^6).
reg [19:0] count_reg;     // 用于消抖计时的计数器
reg key_temp_state;       // 用于跟踪变化的临时状态

initial begin
    key_out_debounced = 1'b0; // 按键非活动状态 (因为是高电平有效)
    key_temp_state    = 1'b0; // 假设按键初始未按下
    count_reg         = 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // 复位处理
        key_out_debounced <= 1'b0;
        key_temp_state    <= 1'b0;
        count_reg         <= 0;
    end else begin
        if (key_in_raw != key_temp_state) begin
            // 原始输入与上次看到的临时状态不同，意味着可能发生变化
            key_temp_state <= key_in_raw; // 更新临时状态
            count_reg      <= 0;          // 重置计数器
        end else begin
            // 原始输入与临时状态相同 (稳定或已改变并等待确认)
            if (count_reg < DEBOUNCE_CYCLES - 1) begin // 计数器未达到消抖周期
                count_reg <= count_reg + 1'b1;
            end else begin
                // 计数器达到最大值，认为 key_temp_state 现在是稳定的
                key_out_debounced <= key_temp_state; // 更新消抖后的输出
            end
        end
    end
end

endmodule
```
### 3.keyboard_scanner.v
```verilog
// 扫描多个按键，对其进行消抖，并输出优先级最高的已按下按键的ID。
module keyboard_scanner #(
    parameter NUM_KEYS = 7,
    parameter DEBOUNCE_TIME_MS = 20
) (
    input clk,                      // 时钟
    input rst_n,                    // 低电平有效复位
    input [NUM_KEYS-1:0] keys_in_raw, // 来自按键的原始输入 (例如, keys_in_raw[0] 代表 Key1)

    output reg [$clog2(NUM_KEYS + 1) - 1 : 0] active_key_id, // 当前激活按键的ID
    output reg key_is_pressed           // 如果有任何按键当前被按下(已消抖)，则为高电平
);
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000); 
// 消抖后的按键状态数组
wire [NUM_KEYS-1:0] keys_debounced_signals;
// 为每个按键实例化消抖器
genvar i;
generate
    for (i = 0; i < NUM_KEYS; i = i + 1) begin : debounce_gen_block
        debouncer #(
            .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES_CALC)
        ) inst_debouncer (
            .clk(clk),
            .rst_n(rst_n),
            .key_in_raw(keys_in_raw[i]),             // 第i个原始按键输入
            .key_out_debounced(keys_debounced_signals[i]) // 第i个消抖后的按键输出
        );
    end
endgenerate
integer j;

always @(*) begin
    key_is_pressed = 1'b0;      // 初始化：假设还没有按键被按下
    // 初始化 active_key_id 为 0 (无按键按下)。确保位宽正确。
    active_key_id = {$clog2(NUM_KEYS + 1){1'b0}};
    // 从最低索引 (Key1, 即 keys_debounced_signals[0]) 迭代到最高。
    // 找到的第一个被按下的键将设置输出。
    for (j = 0; j < NUM_KEYS; j = j + 1) begin
        if (keys_debounced_signals[j]) begin // 如果这个键 'j' 被按下
            if (!key_is_pressed) begin       // 并且如果我们还没有找到一个索引更低的已按下键
                key_is_pressed = 1'b1;     // 设置按下标志
                active_key_id = j + 1;     // 分配其ID (j=0 对应 ID 1, j=1 对应 ID 2, 等等)
            end
        end
    end
end
endmodule
```

### 4.seven_segment_controller.v
```verilog
module seven_segment_controller (
    input clk,    // 时钟
    input rst_n,  // 低电平有效复位
    // SEG0 (后缀/模式指示) 输入
    input [1:0] semitone_type_in,        // 00: 无, 01: 升号 (#), 10: 降号 (b), (2'b11 可能用于特殊指示如 'P')
    input semitone_display_active_flag,  // 如果SEG0需要显示有效的音乐后缀或模式指示，则为真

    // 每个输入是 [2:0], 0 代表空白, 1-7 代表音符 (C-B)
    input [2:0] scrolled_note_seg1_in, // SEG1 (滚动区域最右侧)
    input [2:0] scrolled_note_seg2_in,
    input [2:0] scrolled_note_seg3_in,
    input [2:0] scrolled_note_seg4_in,
    input [2:0] scrolled_note_seg5_in,
    input [2:0] scrolled_note_seg6_in, // SEG6 (滚动区域最左侧)
    // SEG7 (八度/练习反馈) 输入
    input octave_up_active,   // 八度升高激活 (或练习模式的“正确”反馈)
    input octave_down_active, // 八度降低激活 (或练习模式的“错误”反馈)
    // 数码管段选 (a-g, dp) 和 位选 (digit_selects) 输出
    output reg seg_a, output reg seg_b, output reg seg_c, output reg seg_d,
    output reg seg_e, output reg seg_f, output reg seg_g, output reg seg_dp, // dp 通常不用于音符显示
    output reg [7:0] digit_selects // 8位位选信号，分别对应 SEG0 到 SEG7
);
// 7段数码管笔段码定义
localparam PATTERN_0    = 7'b0111111; // 0 (实际显示时可能是音符1-7, 这里是通用数字模板)
localparam PATTERN_1    = 7'b0000110; // 1 (对应音符 C)
localparam PATTERN_2    = 7'b1011011; // 2 (对应音符 D)
localparam PATTERN_3    = 7'b1001111; // 3 (对应音符 E)
localparam PATTERN_4    = 7'b1100110; // 4 (对应音符 F)
localparam PATTERN_5    = 7'b1101101; // 5 (对应音符 G)
localparam PATTERN_6    = 7'b1111101; // 6 (对应音符 A)
localparam PATTERN_7    = 7'b0000111; // 7 (对应音符 B)
localparam PATTERN_BLANK= 7'b0000000; // 空白
localparam PATTERN_H    = 7'b1110110; // '#' (升号, 用 H 表示)
localparam PATTERN_b    = 7'b1111100; // 'b' (降号)
localparam PATTERN_P    = 7'b1100011; // 'P' (练习模式 Practice)
// 八度显示图案 (用于SEG7)
localparam OCTAVE_UP_PATTERN    = 7'b0000001; // 'a' 段亮 (或选择其他如 'H'igh) - 代表八度升高 或 练习“正确”
localparam OCTAVE_NORMAL_PATTERN= 7'b1000000; // 'g' 段亮 (或选择其他如 '-') - 代表正常八度
localparam OCTAVE_DOWN_PATTERN  = 7'b0001000; // 'd' 段亮 (或选择其他如 'L'ow) - 代表八度降低 或 练习“错误”
// 每个显示位置译码后的段数据
reg [6:0] seg_data_suffix;               // 用于SEG0 (后缀/模式指示)
reg [6:0] seg_data_scrolled_notes [1:6]; // 用于SEG1-SEG6的滚动音符数据数组
reg [6:0] seg_data_octave;               // 用于SEG7 (八度/反馈)
// 将音符ID (0-7) 译码为7段笔段码的函数
function [6:0] decode_note_to_segments (input [2:0] note_id);
    case (note_id) // note_id: 0为空白, 1-7为C-B
        3'd1: decode_note_to_segments = PATTERN_1; // C
        3'd2: decode_note_to_segments = PATTERN_2; // D
        3'd3: decode_note_to_segments = PATTERN_3; // E
        3'd4: decode_note_to_segments = PATTERN_4; // F
        3'd5: decode_note_to_segments = PATTERN_5; // G
        3'd6: decode_note_to_segments = PATTERN_6; // A
        3'd7: decode_note_to_segments = PATTERN_7; // B
        default: decode_note_to_segments = PATTERN_BLANK; // 包括 3'd0 (空白)
    endcase
endfunction
// SEG0 半音后缀/模式指示译码器
always @(*) begin
    if (!semitone_display_active_flag) begin // 如果后缀显示未激活
        seg_data_suffix = PATTERN_BLANK;
    end else begin // 根据输入的半音类型译码
        case (semitone_type_in)
            2'b01:  seg_data_suffix = PATTERN_H; // 升号 (#)
            2'b10:  seg_data_suffix = PATTERN_b; // 降号 (b)
            2'b11:  seg_data_suffix = PATTERN_P; // 练习模式指示 'P' (学长修改)
            default: seg_data_suffix = PATTERN_BLANK; // 2'b00 (无半音) 或其他未定义情况
        endcase
    end
end
// SEG1-SEG6 滚动音符译码器
integer k; // Verilog-2001 兼容的循环变量 (如果工具支持，可直接在 for 循环内声明)
always @(*) begin
    // 对每个滚动音符位置的输入进行译码
    seg_data_scrolled_notes[1] = decode_note_to_segments(scrolled_note_seg1_in);
    seg_data_scrolled_notes[2] = decode_note_to_segments(scrolled_note_seg2_in);
    seg_data_scrolled_notes[3] = decode_note_to_segments(scrolled_note_seg3_in);
    seg_data_scrolled_notes[4] = decode_note_to_segments(scrolled_note_seg4_in);
    seg_data_scrolled_notes[5] = decode_note_to_segments(scrolled_note_seg5_in);
    seg_data_scrolled_notes[6] = decode_note_to_segments(scrolled_note_seg6_in);
end
// SEG7 八度/练习反馈译码器
always @(*) begin
    if (octave_up_active && !octave_down_active) begin // 八度升高 或 练习正确
        seg_data_octave = OCTAVE_UP_PATTERN;
    end else if (!octave_up_active && octave_down_active) begin // 八度降低 或 练习错误
        seg_data_octave = OCTAVE_DOWN_PATTERN;
    end else begin // 正常八度 (或两者同时无效/有效，或练习时无特定反馈事件)
        seg_data_octave = OCTAVE_NORMAL_PATTERN;
    end
end
// 8位数码管动态扫描逻辑 (SEG0 到 SEG7)
localparam NUM_DISPLAY_SLOTS = 8; // 数码管位数
// 每个数码管点亮持续时间 (50MHz / 104000 ≈ 480Hz per digit, 480Hz / 8 digits ≈ 60Hz refresh rate for all)
localparam MUX_COUNT_MAX_PER_DIGIT = 104000; // 大约 2.08ms 每位, 整体刷新率约 60Hz
reg [$clog2(MUX_COUNT_MAX_PER_DIGIT)-1:0] mux_counter_reg; // 动态扫描计数器
reg [2:0] current_digit_slot_reg;                        // 当前点亮的数码管位 (0-7)
initial begin // 初始化
    seg_a = 1'b0; seg_b = 1'b0; seg_c = 1'b0; seg_d = 1'b0;
    seg_e = 1'b0; seg_f = 1'b0; seg_g = 1'b0; seg_dp = 1'b0; // dp 通常不亮
    digit_selects = 8'h00; // 所有位选关闭 (假设高电平有效位选)
    mux_counter_reg = 0;
    current_digit_slot_reg = 3'd0; // 从第一位开始扫描
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // 复位处理
        mux_counter_reg <= 0;
        current_digit_slot_reg <= 3'd0;
        digit_selects <= 8'h00; // 关闭所有位
        seg_a <= 1'b0; seg_b <= 1'b0; seg_c <= 1'b0; seg_d <= 1'b0;
        seg_e <= 1'b0; seg_f <= 1'b0; seg_g <= 1'b0; seg_dp <= 1'b0; // 所有段熄灭
    end else begin
        // 动态扫描计数
        if (mux_counter_reg >= MUX_COUNT_MAX_PER_DIGIT - 1) begin // 当前位显示时间到
            mux_counter_reg <= 0; // 重置计数器
            // 切换到下一位数码管
            current_digit_slot_reg <= (current_digit_slot_reg == NUM_DISPLAY_SLOTS - 1) ? 3'd0 : current_digit_slot_reg + 1'b1;
        end else begin
            mux_counter_reg <= mux_counter_reg + 1; // 继续计数
        end
        digit_selects <= 8'h00;
        case (current_digit_slot_reg)
            3'd0: begin // SEG0: 半音后缀 / 模式指示
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_suffix;
                digit_selects[0] <= 1'b1; // 选中SEG0 (假设高电平有效位选)
            end
            3'd1: begin // SEG1: 滚动音符 1
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[1];
                digit_selects[1] <= 1'b1; // 选中SEG1
            end
            3'd2: begin // SEG2: 滚动音符 2
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[2];
                digit_selects[2] <= 1'b1; // 选中SEG2
            end
            3'd3: begin // SEG3: 滚动音符 3
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[3];
                digit_selects[3] <= 1'b1; // 选中SEG3
            end
            3'd4: begin // SEG4: 滚动音符 4
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[4];
                digit_selects[4] <= 1'b1; // 选中SEG4
            end
            3'd5: begin // SEG5: 滚动音符 5
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[5];
                digit_selects[5] <= 1'b1; // 选中SEG5
            end
            3'd6: begin // SEG6: 滚动音符 6
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_scrolled_notes[6];
                digit_selects[6] <= 1'b1; // 选中SEG6
            end
            3'd7: begin // SEG7: 八度状态 / 练习反馈
                {seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a} <= seg_data_octave;
                digit_selects[7] <= 1'b1; // 选中SEG7
            end
            default: digit_selects <= 8'h00; 
        endcase
    end
end
endmodule
```
### 5.piano_recorder.v
```verilog
// 用于录制和回放钢琴按键的模块。
module piano_recorder #(
    parameter CLK_FREQ_HZ      = 50_000_000, // 系统时钟频率
    parameter RECORD_INTERVAL_MS = 20,       // 采样/回放的时间间隔 (例如, 20ms)
    parameter MAX_RECORD_SAMPLES = 512,    // 最大可录制的采样点数
    parameter KEY_ID_BITS      = 3,        // 按键ID的位数 (0表示无, 1-N表示按键) - 默认值, 会被顶层覆盖
    parameter OCTAVE_BITS      = 2         // 八度状态的位数 (00:正常, 01:升, 10:降)
) (
    input clk,                       // 时钟
    input rst_n,                     // 低电平有效复位
    // 控制信号 (期望外部已消抖)
    input record_active_level,       // 当录音按钮 (例如SW16) 按下时为高电平
    input playback_start_pulse,      // 开始回放的单时钟周期脉冲 (例如SW17按下时)
    // 来自主钢琴逻辑的输入 (实时演奏)
    input [KEY_ID_BITS-1:0] live_key_id,       // 当前按下的按键ID (0表示无)
    input live_key_is_pressed,                 // 标志: 当前是否有实时按键按下?
    input live_octave_up,                      // 标志: 实时八度升高是否激活?
    input live_octave_down,                    // 标志: 实时八度降低是否激活?
    // 回放时驱动蜂鸣器和显示的输出
    output reg [KEY_ID_BITS-1:0] playback_key_id,    // 回放的按键ID
    output reg playback_key_is_pressed,           // 回放时按键是否按下
    output wire playback_octave_up,               // 从reg改为wire: 回放时八度升高
    output wire playback_octave_down,             // 从reg改为wire: 回放时八度降低
    // 状态输出 (可选, 用于LED或调试)
    output reg is_recording, // 是否正在录音
    output reg is_playing    // 是否正在回放
);
// --- 派生参数 ---
localparam RECORD_INTERVAL_CYCLES = (RECORD_INTERVAL_MS * (CLK_FREQ_HZ / 1000)); // 每个采样间隔的时钟周期数
localparam ADDR_WIDTH = $clog2(MAX_RECORD_SAMPLES); // 存储器地址位宽
// 每个采样点的数据格式: {八度状态[1:0], 按键是否按下(1位), 按键ID[KEY_ID_BITS-1:0]}
localparam DATA_WIDTH = OCTAVE_BITS + 1 + KEY_ID_BITS;
// --- 用于录音的存储器 ---
// Quartus 会将其推断为RAM (如果可用且大小合适，则为M9K块)
reg [DATA_WIDTH-1:0] recorded_data_memory [0:MAX_RECORD_SAMPLES-1]; // 录音数据存储
reg [ADDR_WIDTH-1:0] record_write_ptr;    // 指向下一个用于录音的空闲位置
reg [ADDR_WIDTH-1:0] playback_read_ptr;   // 指向当前要播放的采样点
reg [ADDR_WIDTH-1:0] last_recorded_ptr;   // 存储最后一个有效录制采样点的地址 + 1 (即录制长度)
// --- 定时器和计数器 ---
reg [$clog2(RECORD_INTERVAL_CYCLES)-1:0] sample_timer_reg; // 采样/回放间隔定时器
// --- 状态机 ---
localparam S_IDLE      = 2'b00; // 空闲状态
localparam S_RECORDING = 2'b01; // 录音状态
localparam S_PLAYBACK  = 2'b10; // 回放状态
reg [1:0] current_state_reg;   // 当前状态寄存器
// --- 用于八度编码/解码的内部信号 ---
wire [OCTAVE_BITS-1:0] live_octave_encoded; // 实时八度编码值
assign live_octave_encoded = (live_octave_up && !live_octave_down) ? 2'b01 :      // 升高
                             (!live_octave_up && live_octave_down) ? 2'b10 :      // 降低
                             2'b00;                                              // 正常 (或同时按下)
reg [OCTAVE_BITS-1:0] playback_octave_encoded; // 从wire改为reg: 回放八度编码值
assign playback_octave_up   = (playback_octave_encoded == 2'b01); // 回放八度升高解码
assign playback_octave_down = (playback_octave_encoded == 2'b10); // 回放八度降低解码
initial begin // 初始化
    is_recording = 1'b0;
    is_playing = 1'b0;
    playback_key_id = {KEY_ID_BITS{1'b0}}; // 确保正确宽度的0值
    playback_key_is_pressed = 1'b0;
    playback_octave_encoded = {OCTAVE_BITS{1'b0}}; // 初始化为正常八度
    current_state_reg = S_IDLE;
    record_write_ptr = {ADDR_WIDTH{1'b0}};
    playback_read_ptr = {ADDR_WIDTH{1'b0}};
    last_recorded_ptr = {ADDR_WIDTH{1'b0}};
    sample_timer_reg = 0; // 假设其位宽足以表示0
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // 复位逻辑
        is_recording <= 1'b0;
        is_playing <= 1'b0;
        playback_key_id <= {KEY_ID_BITS{1'b0}};
        playback_key_is_pressed <= 1'b0;
        playback_octave_encoded <= {OCTAVE_BITS{1'b0}}; // 复位为正常八度
        current_state_reg <= S_IDLE;
        record_write_ptr <= {ADDR_WIDTH{1'b0}};
        playback_read_ptr <= {ADDR_WIDTH{1'b0}};
        last_recorded_ptr <= {ADDR_WIDTH{1'b0}};
        sample_timer_reg <= 0;
    end else begin
        // 默认操作, 可以在状态中覆盖
        if (current_state_reg != S_PLAYBACK) begin // 仅在非主动回放时重置回放输出
             playback_key_is_pressed <= 1'b0;
             playback_key_id <= {KEY_ID_BITS{1'b0}};
             playback_octave_encoded <= {OCTAVE_BITS{1'b0}};
        end
        if (current_state_reg != S_RECORDING) begin // 不在录音状态则清除录音标志
            is_recording <= 1'b0;
        end
        if (current_state_reg != S_PLAYBACK) begin // 不在回放状态则清除回放标志
            is_playing <= 1'b0;
        end
        case (current_state_reg)
            S_IDLE: begin // 空闲状态
                sample_timer_reg <= 0; // 在IDLE状态重置定时器

                if (record_active_level) begin // SW16按下开始录音
                    current_state_reg <= S_RECORDING;        // 进入录音状态
                    record_write_ptr <= {ADDR_WIDTH{1'b0}}; // 从头开始录音
                    is_recording <= 1'b1;                  // 设置录音标志
                    last_recorded_ptr <= {ADDR_WIDTH{1'b0}}; // 重置当前录音长度
                end else if (playback_start_pulse && last_recorded_ptr > 0) begin // SW17按下且有内容可播放
                    current_state_reg <= S_PLAYBACK;         // 进入回放状态
                    playback_read_ptr <= {ADDR_WIDTH{1'b0}}; // 从头开始回放
                    is_playing <= 1'b1;                     // 设置回放标志
                    sample_timer_reg <= RECORD_INTERVAL_CYCLES -1; // 预加载定时器以立即播放第一个采样点
                end
            end

            S_RECORDING: begin // 录音状态
                is_recording <= 1'b1; // 保持 is_recording 为高
                if (!record_active_level || record_write_ptr >= MAX_RECORD_SAMPLES) begin // SW16释放或存储已满
                    current_state_reg <= S_IDLE; // 返回空闲状态
                    last_recorded_ptr <= record_write_ptr; // 保存录制了多少 (采样点数量)
                end else begin // 继续录音
                    if (sample_timer_reg == RECORD_INTERVAL_CYCLES - 1) begin // 达到采样间隔
                        sample_timer_reg <= 0; // 重置定时器
                        // 存储: {八度状态[1:0], 实时按键是否按下, 实时按键ID[KEY_ID_BITS-1:0]}
                        recorded_data_memory[record_write_ptr] <= {live_octave_encoded, live_key_is_pressed, live_key_id};
                        
                        if (record_write_ptr < MAX_RECORD_SAMPLES - 1 ) begin // 如果内存未满
                           record_write_ptr <= record_write_ptr + 1; // 写指针后移
                        end else begin // 内存已满 (最后一个槽已用)
                           current_state_reg <= S_IDLE; // 返回空闲
                           last_recorded_ptr <= MAX_RECORD_SAMPLES; // 记录内存已满
                        end
                    end else begin // 未达到采样间隔
                        sample_timer_reg <= sample_timer_reg + 1; // 定时器递增
                    end
                end
            end
            S_PLAYBACK: begin // 回放状态
                is_playing <= 1'b1; // 保持 is_playing 为高
                // 检查回放是否应停止
                if (playback_read_ptr >= last_recorded_ptr || playback_read_ptr >= MAX_RECORD_SAMPLES ) begin // 已达到录制末尾或内存边界
                    current_state_reg <= S_IDLE; // 返回空闲
                    // is_playing 和回放输出将通过默认操作或进入IDLE状态时重置
                end else begin // 继续回放
                    if (sample_timer_reg == RECORD_INTERVAL_CYCLES - 1) begin // 达到回放间隔
                        sample_timer_reg <= 0; // 重置定时器
                        // 读取数据: {八度状态, 按键是否按下, 按键ID}
                        {playback_octave_encoded, playback_key_is_pressed, playback_key_id} <= recorded_data_memory[playback_read_ptr];
                        
                        if (playback_read_ptr < MAX_RECORD_SAMPLES - 1 && playback_read_ptr < last_recorded_ptr -1 ) begin // 如果未到数据末尾
                            playback_read_ptr <= playback_read_ptr + 1; // 读指针后移
                        end else begin // 已到达要播放的数据末尾或最后一个有效采样点
                            current_state_reg <= S_IDLE; // 返回空闲
                        end
                    end else begin // 未达到回放间隔
                        sample_timer_reg <= sample_timer_reg + 1; // 定时器递增
                    end
                end
            end
            default: current_state_reg <= S_IDLE; // 默认返回空闲状态
        endcase
    end
end
endmodule
```
### 6.song_player.v
```verilog
// 歌曲播放器模块
module song_player #(
    parameter CLK_FREQ_HZ = 50_000_000, // 系统时钟频率
    parameter KEY_ID_BITS = 4,         // 用于表示音符ID
    parameter OCTAVE_BITS = 2          // 用于表示低、中、高八度
) (
    input clk,                   // 时钟
    input rst_n,                 // 低电平有效复位
    input play_active_level,     // 高电平播放，低电平停止 (或播放完成自动停止)

    output reg [KEY_ID_BITS-1:0] song_key_id,   // 输出: 当前歌曲的音符ID
    output reg song_key_is_pressed,             // 输出: 当前歌曲音符是否按下 (非休止符)
    output reg song_octave_up_feed,             // 新增输出: 八度升高信号
    output reg song_octave_down_feed,           // 新增输出: 八度降低信号
    output reg is_song_playing                  // 输出: 歌曲是否正在播放的状态指示
);
    // --- 音符定义 (KEY_ID 1-12, 0为休止符) --- 
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
    // --- 时长和乐谱数据定义 ---<---修改乐谱要修改！
    localparam DURATION_BITS = 4;     // 用于表示时长单位的位数 (例如，最多16个单位)
    localparam SONG_DATA_WIDTH = OCTAVE_BITS + KEY_ID_BITS + DURATION_BITS; // ROM中每个条目的数据宽度
    localparam SONG_LENGTH = 277; // 总事件数: 例如 174个音符 + 8个休止符 (这里是示例值)
    localparam BASIC_NOTE_DURATION_MS = 70; // 用于转换的基础音符时长 (毫秒)
    localparam BASIC_NOTE_DURATION_CYCLES = (BASIC_NOTE_DURATION_MS * (CLK_FREQ_HZ / 1000)); 
    localparam MAX_DURATION_UNITS_VAL = (1 << DURATION_BITS) - 1; // 最大时长单位值
    // --- 状态机定义 ---
    localparam S_IDLE   = 1'b0; // 空闲状态
    localparam S_PLAYING= 1'b1; // 播放状态
    // --- 内部寄存器声明 ---
    reg [SONG_DATA_WIDTH-1:0] song_rom [0:SONG_LENGTH-1]; // 歌曲ROM
    reg [$clog2(SONG_LENGTH)-1:0] current_note_index;       // 当前音符在ROM中的索引
    reg [$clog2(BASIC_NOTE_DURATION_CYCLES * MAX_DURATION_UNITS_VAL + 1)-1:0] note_duration_timer;
    reg [DURATION_BITS-1:0] current_note_duration_units;    // 当前音符的持续时长单位
    reg [KEY_ID_BITS-1:0] current_note_id_from_rom;         // 从ROM读取的当前音符ID
    reg [OCTAVE_BITS-1:0] current_octave_code_from_rom;   // 从ROM读取的当前八度编码
    reg state;                                            // 当前状态 (S_IDLE 或 S_PLAYING)
    reg play_active_level_prev;                           // 上一个周期的播放键电平，用于检测上升沿
    initial begin
        // --- "Bad Apple!!" 转录的歌曲数据 (部分示例) ---
        song_rom[  0] = {OCTAVE_MID, REST,      4'd11}; // 初始休止符 时长: 0.7595s (示例计算)
        song_rom[  1] = {OCTAVE_MID, NOTE_B,    4'd3 }; // MIDI 71 (B4), 时长: 0.2152s (示例计算)
        song_rom[  2] = {OCTAVE_HIGH,NOTE_CS,   4'd2 }; // MIDI 73 (C#5), 时长: 0.1424s (示例计算)
        song_rom[  3] = {OCTAVE_HIGH,NOTE_DS,   4'd5 }; // MIDI 75 (D#5), 时长: 0.3591s (示例计算)
        // ...... (此处省略大量乐谱数据)
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
            play_active_level_prev <= play_active_level; 
            if (!play_active_level && state == S_PLAYING) begin
                state <= S_IDLE;             // 返回空闲状态
                song_key_is_pressed <= 1'b0; // 静音
                song_octave_up_feed <= 1'b0;   // 停止时重置八度
                song_octave_down_feed <= 1'b0; // 停止时重置八度
                is_song_playing <= 1'b0;       // 更新状态
            end
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

                        if (current_note_duration_units == 0) begin
                            // 防御性编程: 跳到下一个音符或在末尾停止
                            if (current_note_index < SONG_LENGTH - 1) begin
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
                end
                default: state <= S_IDLE;
            endcase 
        end
    end
endmodule
```
### 7.scrolling_display_buffer.v
```verilog
// 6位数码管滚动显示缓冲区的模块
module scrolling_display_buffer (
    input clk,                         // 时钟
    input rst_n,                       // 低电平有效复位
    input new_note_valid_pulse,        // 当一个新的有效音符被按下时，产生单时钟脉冲
    input [2:0] current_base_note_id_in, // 新音符的基础音符ID (1-7, 对应C-B)
    output reg [2:0] display_data_seg1, // SEG1的显示数据 (滚动区域的最右边)
    output reg [2:0] display_data_seg2,
    output reg [2:0] display_data_seg3,
    output reg [2:0] display_data_seg4,
    output reg [2:0] display_data_seg5,
    output reg [2:0] display_data_seg6  
);
reg [2:0] seg_buffer [0:5];
integer i; // 循环变量
initial begin // 初始化
    display_data_seg1 = 3'd0; // 空白
    display_data_seg2 = 3'd0;
    display_data_seg3 = 3'd0;
    display_data_seg4 = 3'd0;
    display_data_seg5 = 3'd0;
    display_data_seg6 = 3'd0;
    for (i = 0; i < 6; i = i + 1) begin
        seg_buffer[i] = 3'd0; // 初始化缓冲区为空白
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // 复位处理
        // 将所有缓冲位置重置为0 (空白)
        for (i = 0; i < 6; i = i + 1) begin
            seg_buffer[i] <= 3'd0;
        end
    end else begin
        if (new_note_valid_pulse) begin // 当有新音符到来的脉冲时
            // 滚动现有数据: seg_buffer[5] (SEG6) <- seg_buffer[4] (SEG5), 等等。
            // seg_buffer[5] 处最旧的数据被移出。
            seg_buffer[5] <= seg_buffer[4]; 
            seg_buffer[4] <= seg_buffer[3];
            seg_buffer[3] <= seg_buffer[2]; 
            seg_buffer[2] <= seg_buffer[1]; 
            seg_buffer[1] <= seg_buffer[0]; 
            seg_buffer[0] <= current_base_note_id_in;
        end
    end
end
always @(posedge clk or negedge rst_n) begin // 更新输出寄存器
    if (!rst_n) begin // 复位
        display_data_seg1 <= 3'd0;
        display_data_seg2 <= 3'd0;
        display_data_seg3 <= 3'd0;
        display_data_seg4 <= 3'd0;
        display_data_seg5 <= 3'd0;
        display_data_seg6 <= 3'd0;
    end else begin
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

### 8.mode_sequencer.v
```verilog
module mode_sequencer (
    input clk,                                // 时钟
    input rst_n,                              // 低电平有效复位
    input [3:0] current_live_key_id,          // 4位ID: 1-12代表音符, 0代表无按键
    input       current_live_key_pressed,     // 当前是否有实时按键按下?
    output reg  practice_mode_active_pulse    // 当序列匹配时，产生一个单时钟周期的脉冲
);
localparam SEQ_LENGTH = 7; // 你的序列 "2317616" 的长度
function [3:0] get_target_sequence_val (input integer index);
    case (index)
        0: get_target_sequence_val = 4'd2;
        1: get_target_sequence_val = 4'd3;
        2: get_target_sequence_val = 4'd1;
        3: get_target_sequence_val = 4'd7;
        4: get_target_sequence_val = 4'd6;
        5: get_target_sequence_val = 4'd1;
        6: get_target_sequence_val = 4'd6;
        default: get_target_sequence_val = 4'dx;
    endcase
endfunction
localparam TIMEOUT_MS = 2000; // 2 秒
localparam CLK_FREQ_HZ = 50_000_000; // 时钟频率
localparam TIMEOUT_CYCLES = (TIMEOUT_MS * (CLK_FREQ_HZ / 1000)); // 超时对应的时钟周期数
// --- 内部状态和寄存器 ---
reg [$clog2(SEQ_LENGTH > 1 ? SEQ_LENGTH : 2)-1:0] current_match_index; 

reg [3:0] last_pressed_key_id_prev_cycle;
reg [$clog2(TIMEOUT_CYCLES > 1 ? TIMEOUT_CYCLES : 2)-1:0] timeout_counter_reg;
reg sequence_input_active_flag;
initial begin // 初始化
    practice_mode_active_pulse = 1'b0;
    current_match_index = 0;
    last_pressed_key_id_prev_cycle = 4'd0; // 初始无按键
    timeout_counter_reg = 0;
    sequence_input_active_flag = 1'b0;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin // 复位处理
        practice_mode_active_pulse <= 1'b0;
        current_match_index <= 0;
        last_pressed_key_id_prev_cycle <= 4'd0;
        timeout_counter_reg <= 0;
        sequence_input_active_flag <= 1'b0;
    end else begin
        practice_mode_active_pulse <= 1'b0;
        // 超时逻辑
        if (sequence_input_active_flag) begin // 如果正在输入序列
            if (timeout_counter_reg >= TIMEOUT_CYCLES - 1) begin
                // 超时发生，重置序列匹配
                current_match_index <= 0;
                sequence_input_active_flag <= 1'b0;
                timeout_counter_reg <= 0;
            end else begin
                timeout_counter_reg <= timeout_counter_reg + 1'b1; // 超时计数器递增
            end
        end else begin
            timeout_counter_reg <= 0; // 不在序列输入中，重置计时器
        end
        if (current_live_key_pressed && current_live_key_id != 4'd0 && current_live_key_id != last_pressed_key_id_prev_cycle) begin
            timeout_counter_reg <= 0;                 // 在新按键按下时重置超时计时器
            sequence_input_active_flag <= 1'b1;       // 现在我们正在主动输入/检查序列
            if (current_live_key_id == get_target_sequence_val(current_match_index)) begin
                // 按下的键与序列中当前步骤的键匹配
                if (current_match_index == SEQ_LENGTH - 1) begin
                    // 序列的最后一个键已匹配!
                    practice_mode_active_pulse <= 1'b1; // 触发激活脉冲!
                    current_match_index <= 0;           // 为下一次重置
                    sequence_input_active_flag <= 1'b0; // 序列完成，不再活动
                end else begin
                    // 不是最后一个键，但到目前为止是正确的。前进到下一步。
                    current_match_index <= current_match_index + 1'b1;
                end
            end else begin // 按下了序列中不正确的键
                // 如果不正确的键是新目标序列的开始，则从步骤1重新开始匹配
                if (current_live_key_id == get_target_sequence_val(0)) begin
                    current_match_index <= 1; // 匹配了序列的第一个元素
                end else begin
                    current_match_index <= 0; // 错误的键，并且它不是新序列的开始，重置。
                    sequence_input_active_flag <= 1'b0; 
                end
            end
        end
        if (current_live_key_pressed && current_live_key_id != 4'd0) begin
            last_pressed_key_id_prev_cycle <= current_live_key_id;
        end else if (!current_live_key_pressed) begin // 按键已释放
            last_pressed_key_id_prev_cycle <= 4'd0;
        end
    end
end
endmodule
```
### 9.practice_player.v
```verilog
module practice_player #(
    parameter NUM_DISPLAY_SEGMENTS = 6
) (
    input clk,                          // 时钟
    input rst_n,                        // 低电平有效复位
    input practice_mode_active,         // 练习模式是否激活
    input [3:0] current_live_key_id,    // 当前用户按下的实时按键ID (0-12)
    input current_live_key_pressed,     // 用户是否有按键按下
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
reg [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] current_note_index_in_song; 
reg current_live_key_pressed_prev;                                  
reg [$clog2(PRACTICE_SONG_LENGTH + 1)-1:0] next_note_idx_calculated; 
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
// ---时序逻辑 ---
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
        correct_note_played_event <= 1'b0;
        wrong_note_played_event <= 1'b0;
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
                            practice_song_finished_event <= 1'b1;
                        end 
                        current_note_index_in_song <= next_note_idx_calculated; // 更新当前音符索引到下一个
                        update_display_buffer(next_note_idx_calculated);      // 更新数码管显示，从下一个音符开始
                    end else begin // 用户弹错了音符
                        wrong_note_played_event <= 1'b1; // 发出错误事件脉冲
                    end 
                end 
            end
        end else begin
            if (current_note_index_in_song != 0) begin // 如果之前在练习，重置索引和显示
                 current_note_index_in_song <= 0;
                 update_display_buffer(0);
            end 
            if (practice_song_finished_event) begin // 如果之前完成了歌曲，清除完成标志
                practice_song_finished_event <= 1'b0;
            end
        end
    end
end
endmodule
```
### Badapple示例谱子
```v
        song_rom[  0]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[  1]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[  2]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[  3]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[  4]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[  5]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[  6]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[  7]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[  8]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[  9]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 10]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 11]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 12]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 13]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[ 14]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 15]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 16]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 17]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 18]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 19]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 20]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 21]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 22]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[ 23]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[ 24]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 25]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 26]  = { OCTAVE_MID , NOTE_D   , 4'd3 }; // MIDI 62 (D4), Dur: 0.2156s
        song_rom[ 27]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 28]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 29]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 30]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 31]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 32]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[ 33]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[ 34]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[ 35]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 36]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[ 37]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 38]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 39]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 40]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 41]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[ 42]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[ 43]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 44]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 45]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 46]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 47]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 48]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 49]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 50]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 51]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 52]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[ 53]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 54]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 55]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[ 56]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 57]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 58]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 59]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 60]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 61]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[ 62]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[ 63]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[ 64]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[ 65]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 66]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 67]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 68]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 69]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 70]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 71]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[ 72]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[ 73]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 74]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 75]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 76]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 77]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 78]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 79]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 80]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 81]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[ 82]  = { OCTAVE_MID , NOTE_D   , 4'd3 }; // MIDI 62 (D4), Dur: 0.2155s
        song_rom[ 83]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 84]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 85]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 86]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 87]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 88]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[ 89]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[ 90]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[ 91]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[ 92]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[ 93]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[ 94]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[ 95]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[ 96]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 97]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[ 98]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[ 99]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[100]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[101]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[102]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[103]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[104]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[105]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[106]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[107]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[108]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[109]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[110]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[111]  = { OCTAVE_MID , REST     , 4'd3 }; // Rest dur: 0.2192s
        song_rom[112]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[113]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[114]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[115]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[116]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[117]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[118]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[119]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[120]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[121]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[122]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[123]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[124]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[125]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[126]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[127]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[128]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[129]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[130]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2156s
        song_rom[131]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4329s
        song_rom[132]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2156s
        song_rom[133]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[134]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[135]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[136]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[137]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[138]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[139]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[140]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[141]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[142]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[143]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[144]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[145]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[146]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[147]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[148]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[149]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[150]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[151]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[152]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[153]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3242s
        song_rom[154]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[155]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[156]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[157]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[158]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[159]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[160]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2156s
        song_rom[161]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[162]  = { OCTAVE_LOW , NOTE_AS  , 4'd3 }; // MIDI 61 (A#3), Dur: 0.2155s
        song_rom[163]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[164]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[165]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[166]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[167]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[168]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[169]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[170]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[171]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[172]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[173]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[174]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[175]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[176]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[177]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[178]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[179]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[180]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[181]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[182]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[183]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[184]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[185]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[186]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[187]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[188]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2155s
        song_rom[189]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[190]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[191]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[192]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[193]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[194]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[195]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[196]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[197]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[198]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[199]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[200]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[201]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[202]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[203]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[204]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[205]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[206]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[207]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[208]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[209]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[210]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[211]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[212]  = { OCTAVE_HIGH, NOTE_FS  , 4'd3 }; // MIDI 78 (F#5), Dur: 0.2156s
        song_rom[213]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[214]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[215]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[216]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[217]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[218]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[219]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[220]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[221]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[222]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[223]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[224]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[225]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[226]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[227]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[228]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[229]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[230]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[231]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[232]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[233]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[234]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[235]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[236]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[237]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[238]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[239]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[240]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[241]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[242]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[243]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[244]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[245]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[246]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[247]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[248]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[249]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[250]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[251]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2155s
        song_rom[252]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[253]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
        song_rom[254]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[255]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[256]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[257]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[258]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[259]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[260]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[261]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[262]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[263]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[264]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[265]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[266]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[267]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[268]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[269]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[270]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[271]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[272]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[273]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2155s
        song_rom[274]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2155s
        song_rom[275]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[276]  = { OCTAVE_MID , NOTE_DS  , 4'd6 }; // MIDI 63 (D#4), Dur: 0.4330s
        song_rom[277]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[278]  = { OCTAVE_MID , NOTE_DS  , 4'd3 }; // MIDI 63 (D#4), Dur: 0.2156s
        song_rom[279]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[280]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[281]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[282]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[283]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3242s
        song_rom[284]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[285]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[286]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[287]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2156s
        song_rom[288]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[289]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[290]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[291]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4330s
        song_rom[292]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[293]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2155s
        song_rom[294]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[295]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[296]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[297]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[298]  = { OCTAVE_MID , NOTE_AS  , 4'd5 }; // MIDI 70 (A#4), Dur: 0.3243s
        song_rom[299]  = { OCTAVE_MID , REST     , 4'd2 }; // Rest dur: 0.1105s
        song_rom[300]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2156s
        song_rom[301]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[302]  = { OCTAVE_HIGH, NOTE_FS  , 4'd3 }; // MIDI 78 (F#5), Dur: 0.2156s
        song_rom[303]  = { OCTAVE_HIGH, NOTE_F   , 4'd3 }; // MIDI 77 (F5), Dur: 0.2156s
        song_rom[304]  = { OCTAVE_HIGH, NOTE_DS  , 4'd3 }; // MIDI 75 (D#5), Dur: 0.2155s
        song_rom[305]  = { OCTAVE_HIGH, NOTE_CS  , 4'd3 }; // MIDI 73 (C#5), Dur: 0.2155s
        song_rom[306]  = { OCTAVE_MID , NOTE_AS  , 4'd6 }; // MIDI 70 (A#4), Dur: 0.4329s
        song_rom[307]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[308]  = { OCTAVE_MID , NOTE_AS  , 4'd3 }; // MIDI 70 (A#4), Dur: 0.2156s
        song_rom[309]  = { OCTAVE_MID , NOTE_GS  , 4'd3 }; // MIDI 68 (G#4), Dur: 0.2156s
        song_rom[310]  = { OCTAVE_MID , NOTE_FS  , 4'd3 }; // MIDI 66 (F#4), Dur: 0.2156s
        song_rom[311]  = { OCTAVE_MID , NOTE_F   , 4'd3 }; // MIDI 65 (F4), Dur: 0.2156s
        song_rom[312]  = { OCTAVE_MID , NOTE_CS  , 4'd3 }; // MIDI 61 (C#4), Dur: 0.2156s
        song_rom[313]  = { OCTAVE_MID , NOTE_DS  , 4'd5 }; // MIDI 63 (D#4), Dur: 0.3243s
```









