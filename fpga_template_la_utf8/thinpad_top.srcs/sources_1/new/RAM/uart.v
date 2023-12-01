`define Serial_Status_ADD  32'hBFD003FC
`define Serial_Data_ADD    32'hBFD003F8


module my_uart (
    input               clk               ,
    input               resetn            ,
    output    wire       txd,  //直连串口发送端
    input     wire       rxd,  //直连串口接收端
    output              is_Serial_Status    ,
    output              is_Serial_Data      ,

    // CPU RAM signal
    input              cpu_sram_en      ,
    input       [ 3:0] cpu_sram_we      ,
    input       [31:0] cpu_sram_addr    ,
    input       [31:0] cpu_sram_wdata   ,
    output reg  [31:0] cpu_sram_rdata   
);
    //直连串口接收发送演示，从直连串口收到的数据再发送出去
wire [7:0]  ext_uart_rx;
reg  [7:0]  ext_uart_buffer, ext_uart_tx;
wire        ext_uart_ready, ext_uart_busy;
reg         ext_uart_start;
reg         ext_uart_clear;
    
//接收模块，9600无检验位
async_receiver #(.ClkFrequency(50000000),.Baud(9600)) 
    ext_uart_r(
        .clk(clk),                       // in 外部时钟信号
        .RxD(rxd),                           // in 外部串行信号输入
        .RxD_data_ready(ext_uart_ready),     // out数据接收到标志
        .RxD_clear(ext_uart_clear),          // in 清除接收标志
        .RxD_data(ext_uart_rx)               // out接收到的一字节数据
    );
//发送模块，9600无检验位
async_transmitter #(.ClkFrequency(50000000),.Baud(9600)) 
    ext_uart_t(
        .clk(clk),                  // in 外部时钟信号
        .TxD(txd),                      // out串行信号输出
        .TxD_busy(ext_uart_busy),       // out发送器忙状态指示
        .TxD_start(ext_uart_start),     // in 开始发送信号
        .TxD_data(ext_uart_tx)          // in 待发送的数据
    );


assign is_Serial_Status = cpu_sram_addr == `Serial_Status_ADD;
assign is_Serial_Data   = cpu_sram_addr == `Serial_Data_ADD;

reg[31:0] serial_o;
wire[31:0] base_ram_o;
wire[31:0] ext_ram_o;

/// 处理串口
always @(posedge clk) begin
    if(resetn) begin
        ext_uart_start <= 1'b0;
        serial_o <= 32'h0000_0000;
        ext_uart_tx <= 8'h00;
    end
    else begin
        if(is_Serial_Status) begin                                       // 操作目标为串口状态
            serial_o       <= {30'b0, ext_uart_ready, !ext_uart_busy};   // 是否收到数据，串口是否空闲（可发送数据）
            ext_uart_start <= 1'b0;
            ext_uart_tx    <= 8'h00;
        end

        else if(is_Serial_Data) begin                    /// 操作目标为串口数据(8位)
            if (~cpu_sram_we) begin                        /// 读数据，即接收串口数据
                serial_o <= {24'h000000, ext_uart_rx};   //  低8位为所需的字节
                ext_uart_start <= 1'b0;
                ext_uart_tx <= 8'h00;
            end
            else if (cpu_sram_we) begin                                   /// 写数据，即串口发送数据
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

always @(posedge clk) begin
    if(resetn) begin
        ext_uart_clear_next <= 1'b0;
    end
    else begin
        if(ext_uart_ready && is_Serial_Data && ~cpu_sram_we && ext_uart_clear_next == 1'b0) begin
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

endmodule