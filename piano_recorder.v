// 文件: piano_recorder.v
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
                    // is_recording 将通过默认操作或进入IDLE状态时设置为0
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