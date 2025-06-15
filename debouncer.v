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