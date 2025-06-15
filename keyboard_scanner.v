// 文件: keyboard_scanner.v
// 扫描多个按键，对其进行消抖，并输出优先级最高的已按下按键的ID。

module keyboard_scanner #(
    parameter NUM_KEYS = 7,         // 默认值，顶层模块会覆盖 (例如，改为12)
    parameter DEBOUNCE_TIME_MS = 20 // 消抖时间 (毫秒)
) (
    input clk,                      // 时钟
    input rst_n,                    // 低电平有效复位
    input [NUM_KEYS-1:0] keys_in_raw, // 来自按键的原始输入 (例如, keys_in_raw[0] 代表 Key1)

    // 输出ID可以是0 (无按键) 或 1 到 NUM_KEYS。
    // 所以，它需要表示 NUM_KEYS + 1 个不同的值。
    // 所需位宽是 $clog2(NUM_KEYS + 1)。
    // 示例: NUM_KEYS = 7 -> $clog2(8) = 3 位 (用于0-7)
    // 示例: NUM_KEYS = 12 -> $clog2(13) = 4 位 (用于0-12)
    output reg [$clog2(NUM_KEYS + 1) - 1 : 0] active_key_id, // 当前激活按键的ID
    output reg key_is_pressed           // 如果有任何按键当前被按下(已消抖)，则为高电平
);

// 根据50MHz时钟计算消抖周期 (通过 DEBOUNCE_TIME_MS 传入)
localparam DEBOUNCE_CYCLES_CALC = (DEBOUNCE_TIME_MS * 50000); // 假设时钟为50MHz

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

// 如果旧的工具需要，为Verilog-2001兼容性声明循环变量
// 对于现代工具，如果不想为综合使用 'automatic'，可以直接在for循环中声明 'j'。
integer j;

// 确定 active_key_id 和 key_is_pressed 的逻辑
// 优先级: 如果多个键被按下，索引最低的键 (keys_debounced_signals[0]) 优先。
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