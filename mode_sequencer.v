// 文件: mode_sequencer.v (已校正和优化)
// 模式序列器模块，用于检测特定按键序列以激活某种模式（例如练习模式）
module mode_sequencer (
    input clk,                                // 时钟
    input rst_n,                              // 低电平有效复位

    // 来自主钢琴逻辑的输入 (已消抖的、优先级最高的按键ID)
    input [3:0] current_live_key_id,          // 4位ID: 1-12代表音符, 0代表无按键
    input       current_live_key_pressed,     // 当前是否有实时按键按下?

    // 输出，指示练习模式激活
    output reg  practice_mode_active_pulse    // 当序列匹配时，产生一个单时钟周期的脉冲
);

// --- 序列参数 ---
localparam SEQ_LENGTH = 7; // 你的序列 "2317616" 的长度
// 已校正: TARGET_SEQUENCE 的单行赋值，请确保Quartus中的Verilog版本为2001或SystemVerilog
// 使用函数定义目标序列中的每个值
function [3:0] get_target_sequence_val (input integer index);
    case (index) // 根据索引返回序列中对应的目标按键ID
        0: get_target_sequence_val = 4'd2; // 序列第1个: ID 2 (D)
        1: get_target_sequence_val = 4'd3; // 序列第2个: ID 3 (E)
        2: get_target_sequence_val = 4'd1; // 序列第3个: ID 1 (C)
        3: get_target_sequence_val = 4'd7; // 序列第4个: ID 7 (B)
        4: get_target_sequence_val = 4'd6; // 序列第5个: ID 6 (A)
        5: get_target_sequence_val = 4'd1; // 序列第6个: ID 1 (C)
        6: get_target_sequence_val = 4'd6; // 序列第7个: ID 6 (A)
        default: get_target_sequence_val = 4'dx; // 或其他默认值 (例如4'd0)
    endcase
endfunction
// 然后在你的逻辑中:
// if (current_live_key_id == get_target_sequence_val(current_match_index)) begin

// 序列输入的超时时间 (例如，按键之间间隔2秒)
localparam TIMEOUT_MS = 2000; // 2 秒
localparam CLK_FREQ_HZ = 50_000_000; // 时钟频率
localparam TIMEOUT_CYCLES = (TIMEOUT_MS * (CLK_FREQ_HZ / 1000)); // 超时对应的时钟周期数

// --- 内部状态和寄存器 ---
// 校正 current_match_index 的位宽，以安全地保存0到SEQ_LENGTH的状态 (例如，0-6用于匹配，7用于'完成'或使用0到SEQ_LENGTH-1作为索引)
// 它需要保存从0到SEQ_LENGTH-1的值作为索引。
// $clog2(SEQ_LENGTH) 给出0到SEQ_LENGTH-1所需的位数。如果SEQ_LENGTH=7，则需要3位(0-6)。
reg [$clog2(SEQ_LENGTH > 1 ? SEQ_LENGTH : 2)-1:0] current_match_index; // 当前匹配序列的索引 (例如，SEQ_LENGTH=7时为[2:0])

reg [3:0] last_pressed_key_id_prev_cycle; // 存储上一周期的按键ID，以检测新的按键按下事件
reg [$clog2(TIMEOUT_CYCLES > 1 ? TIMEOUT_CYCLES : 2)-1:0] timeout_counter_reg; // 超时计数器
reg sequence_input_active_flag;           // 标志，指示是否正在输入序列的过程中

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
        // 默认: 脉冲为低，除非明确设置为高一个周期
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

        // 按键检测和序列匹配逻辑
        // 新的按键按下事件定义为：当前有键按下，且当前键ID与上周期不同，并且当前键ID不为0(休止符)。
        if (current_live_key_pressed && current_live_key_id != 4'd0 && current_live_key_id != last_pressed_key_id_prev_cycle) begin
            // 这是一个新的、有效的音乐按键按下事件
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

        // 为下一个时钟周期更新 last_pressed_key_id_prev_cycle
        // 如果有键按下，存储其ID。如果无键按下，存储0。
        if (current_live_key_pressed && current_live_key_id != 4'd0) begin
            last_pressed_key_id_prev_cycle <= current_live_key_id;
        end else if (!current_live_key_pressed) begin // 按键已释放
            last_pressed_key_id_prev_cycle <= 4'd0;
        end
        // 如果按键被按住 (current_live_key_id == last_pressed_key_id_prev_cycle), 
        // last_pressed_key_id_prev_cycle 保持不变, 上面的主要 `if` 条件不会因“新按下”而触发。
    end
end

endmodule