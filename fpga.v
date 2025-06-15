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