// 文件: seven_segment_controller.v
// 修改后用于显示:
// - SEG0: 当前半音后缀 (#/b) 或 练习模式指示符 (例如 'P')
// - SEG1-SEG6: 滚动的音符数字 (来自 scrolling_display_buffer 或 practice_player)
// - SEG7: 八度状态 或 练习模式反馈
module seven_segment_controller (
    input clk,    // 时钟
    input rst_n,  // 低电平有效复位

    // SEG0 (后缀/模式指示) 输入
    input [1:0] semitone_type_in,        // 00: 无, 01: 升号 (#), 10: 降号 (b), (2'b11 可能用于特殊指示如 'P')
    input semitone_display_active_flag,  // 如果SEG0需要显示有效的音乐后缀或模式指示，则为真

    // SEG1-SEG6 (滚动音符数字) 输入 (来自缓冲模块)
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

// 7段数码管笔段码定义 (共阳极或共阴极，根据实际硬件调整，此处假设高电平点亮某段)
// 格式: {g,f,e,d,c,b,a} (标准顺序可能不同，请核对)
// 假设 '1' 代表点亮该段, '0' 代表熄灭. (如果共阳极，则相反)
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
localparam PATTERN_P    = 7'b1100011; // 'P' (练习模式 Practice) - (学长添加)

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
        // 默认先关闭所有段和位选，防止上一个周期的残留影响下一个位 (通常称为"ghosting"的消除措施之一)
        // 但如果 MUX_COUNT_MAX_PER_DIGIT 足够长，且切换时序正确，可以不每次都清零。
        // 为保险起见，或在切换位之前先关闭所有位，然后开启新位。
        // 当前代码是在case语句中直接选择位并送出段码，只要时序没问题也可。
        // 如果数码管是共阴极，位选高有效，段选高有效点亮。
        // 如果是共阳极，位选低有效，段选低有效点亮。假设是前者。

        // 动态扫描计数
        if (mux_counter_reg >= MUX_COUNT_MAX_PER_DIGIT - 1) begin // 当前位显示时间到
            mux_counter_reg <= 0; // 重置计数器
            // 切换到下一位数码管
            current_digit_slot_reg <= (current_digit_slot_reg == NUM_DISPLAY_SLOTS - 1) ? 3'd0 : current_digit_slot_reg + 1'b1;
        end else begin
            mux_counter_reg <= mux_counter_reg + 1; // 继续计数
        end

        // 根据当前扫描到的数码管位 (current_digit_slot_reg)，选择相应的段数据和位选信号
        // 注意: 对输出端口 'seg_a'...'seg_g' 和 'digit_selects' 的赋值应该使用非阻塞赋值 '<='
        // (你的代码已正确使用)
        // 先关闭所有位选，再打开当前位
        digit_selects <= 8'h00; // (学长注: 更好的做法是 `digit_selects <= 8'b0;` 然后再 `digit_selects[current_digit_slot_reg] <= 1'b1;`
                               // 或者直接在case中像你这样做。如果 `digit_selects` 是低电平有效，则逻辑相反)
                               // 你的 `digit_selects[index] <= 1'b1;` 假设位选高电平有效。
                               // 如果开发板数码管位选是低电平有效，则应为 `digit_selects[index] <= 1'b0;` 且其他位为 `1'b1` (或用 `~` 操作)。
                               // 常见的位选信号是类似 `8'b11111110` (SEG0选中), `8'b11111101` (SEG1选中) 如果是低有效。

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
            default: digit_selects <= 8'h00; // 理论上不会到这里，但作为安全措施
        endcase
        // seg_dp (小数点) 在此设计中未使用，保持默认的熄灭状态 (seg_dp <= 1'b0; 已在always块开头或initial中设置)
    end
end
endmodule