// 文件: scrolling_display_buffer.v
// 管理一个6位数码管滚动显示缓冲区的模块 (用于SEG1-SEG6)

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
    output reg [2:0] display_data_seg6  // SEG6的显示数据 (滚动区域的最左边)
);

// 6个数码管段 (SEG1 到 SEG6) 的内部缓冲寄存器
// seg_buffer[0] 对应 display_data_seg1 (滚动显示的最右侧)
// seg_buffer[5] 对应 display_data_seg6 (滚动显示的最左侧)
reg [2:0] seg_buffer [0:5]; // 每个元素存储一个3位的音符ID (0表示空白)

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
            seg_buffer[5] <= seg_buffer[4]; // SEG6_data <--- SEG5_data
            seg_buffer[4] <= seg_buffer[3]; // SEG5_data <--- SEG4_data
            seg_buffer[3] <= seg_buffer[2]; // SEG4_data <--- SEG3_data
            seg_buffer[2] <= seg_buffer[1]; // SEG3_data <--- SEG2_data
            seg_buffer[1] <= seg_buffer[0]; // SEG2_data <--- SEG1_data

            // 将新音符加载到第一个位置 (SEG1)
            seg_buffer[0] <= current_base_note_id_in; // SEG1_data <--- 新音符
        end
        // 无 else: 如果 new_note_valid_pulse 不为高，则缓冲区保持其值。
    end
end

// 持续将缓冲区内容分配给输出
// (为了清晰，从缓冲寄存器到输出寄存器的组合分配，
//  或者如果希望是wire类型，可以直接在seven_segment_controller中使用seg_buffer[x])
// 为确保输出也能正确复位并避免锁存器（如果输出是wire类型），
// 从寄存的缓冲值分配它们更清晰。

// 我们已将输出声明为 'reg'，并将直接为它们赋值。
// 我们需要确保它们在时钟块中更新，或者从缓冲区更新
// （如果它们是wire，则以组合方式）。
// 由于输出是 'reg'，我们根据 'seg_buffer' 更新它们。
// 通常好的做法是，由内部寄存器驱动的模块输出
// 应从这些寄存器组合赋值，或者输出本身就是寄存器。
// 这里，我们将输出设为 'reg'，所以我们应该在always块中给它们赋值。
// 如果输出是 'reg'，一个更简单的方法是在时钟块中更新缓冲区后直接赋值。

always @(posedge clk or negedge rst_n) begin // 更新输出寄存器
    if (!rst_n) begin // 复位
        display_data_seg1 <= 3'd0;
        display_data_seg2 <= 3'd0;
        display_data_seg3 <= 3'd0;
        display_data_seg4 <= 3'd0;
        display_data_seg5 <= 3'd0;
        display_data_seg6 <= 3'd0;
    end else begin
        // 从缓冲区内容更新输出
        display_data_seg1 <= seg_buffer[0];
        display_data_seg2 <= seg_buffer[1];
        display_data_seg3 <= seg_buffer[2];
        display_data_seg4 <= seg_buffer[3];
        display_data_seg5 <= seg_buffer[4];
        display_data_seg6 <= seg_buffer[5];
    end
end

endmodule