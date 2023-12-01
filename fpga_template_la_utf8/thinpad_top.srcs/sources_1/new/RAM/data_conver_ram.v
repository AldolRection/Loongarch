`define Serial_Status_ADD  32'hBFD003FC
`define Serial_Data_ADD    32'hBFD003F8


module data_conver_ram (
    input               clk               ,
    input               resetn            ,

    // input              is_Serial_Data,
    // input              is_Serial_Status,
    // input       [31:0] serial_o,

    // CPU RAM signal
    input              cpu_sram_en      ,
    input       [ 3:0] cpu_sram_we      ,
    input       [31:0] cpu_sram_addr    ,
    input       [31:0] cpu_sram_wdata   ,
    output reg  [31:0] cpu_sram_rdata   ,

    // BaseRAM/ExtRAM signal
    inout  wire[31:0]  ram_data,        //RAM数据，低8位与CPLD串口控制器共享
    output wire[19:0]  ram_addr,        //RAM地址
    output wire[ 3:0]  ram_be_n,        //RAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire        ram_ce_n,        //RAM片选，低有效
    output wire        ram_oe_n,        //RAM读使能，低有效
    output wire        ram_we_n,        //RAM写使能，低有效

    output reg         is_base
);


//直连串口接收发送演示，从直连串口收到的数据再发送出去
wire [7:0]  ext_uart_rx;
reg  [7:0]  ext_uart_buffer, ext_uart_tx;
wire        ext_uart_ready;//< 接收器收到数据完成之后，置为1
wire        ext_uart_busy; //发送器状态是否忙碌，1为忙碌，0为不忙碌
reg         ext_uart_start;//< 传递给发送器，为1时，代表可以发送，为0时，代表不发送
reg         ext_uart_clear;//< 置1，在下次时钟有效的时候，会清除接收器的标志位
    
//接收模块，9600无检验位
async_receiver #(.ClkFrequency(50000000),.Baud(9600)) 
    ext_uart_r(
        .clk(clk),                           // in 外部时钟信号
        .RxD(rxd),                           // in 外部串行信号输入
        .RxD_data_ready(ext_uart_ready),     // out数据接收到标志
        .RxD_clear(ext_uart_clear),          // in 清除接收标志
        .RxD_data(ext_uart_rx)               // out接收到的一字节数据
    );
//发送模块，9600无检验位
async_transmitter #(.ClkFrequency(50000000),.Baud(9600)) 
    ext_uart_t(
        .clk(clk),                      // in 外部时钟信号
        .TxD(txd),                      // out串行信号输出
        .TxD_busy(ext_uart_busy),       // out发送器忙状态指示
        .TxD_start(ext_uart_start),     // in 开始发送信号
        .TxD_data(ext_uart_tx)          // in 待发送的数据
    );


wire is_Serial_Status = cpu_sram_addr == `Serial_Status_ADD;
wire is_Serial_Data   = cpu_sram_addr == `Serial_Data_ADD;

// assign is_base = ~is_Serial_Status && ~is_Serial_Data && (cpu_sram_addr < 32'h8040_0000);
always @(posedge clk or negedge resetn) begin
    if (resetn) begin
        is_base <= 1'b0;
    end else if (~is_Serial_Status && ~is_Serial_Data && (cpu_sram_addr < 32'h8040_0000)) begin
        is_base <= 1'b1;
    end else begin
        is_base <= 1'b0;
    end
end

reg  [31:0] serial_o;

/// 处理串口
always @(posedge clk) begin
    if(resetn) begin
        ext_uart_start <= 1'b0;
        serial_o <= 32'h0000_0000;
        ext_uart_tx <= 8'h00;
    end
    else begin
        if(is_Serial_Status) begin                                       // 操作目标为串口状态
            serial_o       <= {30'b0, ext_uart_ready, ~ext_uart_busy};   // 是否收到数据，串口是否空闲（可发送数据）
            ext_uart_start <= 1'b0;
            ext_uart_tx    <= 8'h00;
        end

        else if(is_Serial_Data) begin                    /// 操作目标为串口数据(8位)
            if (~(|cpu_sram_we)) begin                      /// 读数据，即接收串口数据
                serial_o <= {24'h000000, ext_uart_rx};   //  低8位为所需的字节
                ext_uart_start <= 1'b0;
                ext_uart_tx <= 8'h00;
            end
            else if (|cpu_sram_we) begin                                   /// 写数据，即串口发送数据
                ext_uart_tx <= cpu_sram_wdata[7:0];
                ext_uart_start <= 1'b1;
                serial_o <= 32'h0000_0000;
            end
        end

        else begin
            ext_uart_start <= 1'b0;
            serial_o <= 32'h0000_0000;
            ext_uart_tx <= 8'h00;
        end
    end
end

/// 处理串口接收的clear
reg     ext_uart_clear_next;
// reg[3:0] ext_uart_clear_para;

always @(negedge clk) begin
    if(resetn) begin
        ext_uart_clear_next <= 1'b0;
    end
    else begin
        if(ext_uart_ready && is_Serial_Data && ~(|cpu_sram_we) && (ext_uart_clear_next == 1'b0)) begin
            ext_uart_clear_next <= 1'b1;  // 收到数据，清除标志，因为数据已经取出了
        end
        else if (ext_uart_clear == 1'b1) begin
            ext_uart_clear_next <= 1'b0;
        end
        else begin
            ext_uart_clear_next <= ext_uart_clear_next;
        end
    end
end

always @(posedge clk) begin
    if(resetn) begin
        ext_uart_clear <= 1'b0;
    end
    else begin
        if(ext_uart_clear_next) begin
            ext_uart_clear <= 1'b1;
        end
        else begin
            ext_uart_clear <= 1'b0;
        end
    end
end



// most import is ram_be_n signal
// if write, cpu_we=1(high si valid), ram_be_n=0(low is valid)
// if read , ram_be_n=0000(low is valid)
// assign sram_be_n = ~(|wen&&en ? wen : 4'hf);

assign ram_ce_n = ~cpu_sram_en || is_Serial_Status || is_Serial_Data || is_base;

assign ram_be_n = ( |cpu_sram_we && cpu_sram_en) ? ~cpu_sram_we : 4'h0;
assign ram_we_n = ~( |cpu_sram_we && cpu_sram_en);
assign ram_oe_n = ( |cpu_sram_we && cpu_sram_en);
// word addressing, so div 4
assign ram_addr = cpu_sram_addr[21:2];

assign ram_data = ~ram_we_n ? cpu_sram_wdata : 32'hz;

always @(posedge clk or negedge resetn) begin
    if (resetn) begin
        cpu_sram_rdata <= 32'hz;
    end else if (~ram_oe_n) begin
        cpu_sram_rdata <= is_Serial_Status || is_Serial_Data ? serial_o : ram_data;
    end
end

endmodule