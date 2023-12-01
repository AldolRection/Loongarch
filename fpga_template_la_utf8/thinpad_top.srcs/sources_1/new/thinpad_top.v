`default_nettype none

`define Serial_Status_ADD  32'hBFD003FC
`define Serial_Data_ADD    32'hBFD003F8

module thinpad_top(
    input wire clk_50M,           //50MHz 时钟输入
    input wire clk_11M0592,       //11.0592MHz 时钟输入（备用，可不用）

    input wire clock_btn,         //BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  wire[3:0]  touch_btn,  //BTN1~BTN4，按钮开关，按下时为1
    input  wire[31:0] dip_sw,     //32位拨码开关，拨到“ON”时为1
    output wire[15:0] leds,       //16位LED，输出时1点亮
    output wire[7:0]  dpy0,       //数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,       //数码管高位信号，包括小数点，输出1点亮

    //BaseRAM信号
    inout  wire[31:0] base_ram_data,        //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr,        //BaseRAM地址
    output wire[ 3:0] base_ram_be_n,        //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire       base_ram_ce_n,        //BaseRAM片选，低有效
    output wire       base_ram_oe_n,        //BaseRAM读使能，低有效
    output wire       base_ram_we_n,        //BaseRAM写使能，低有效

    //ExtRAM信号
    inout  wire[31:0] ext_ram_data,         //ExtRAM数据
    output wire[19:0] ext_ram_addr,         //ExtRAM地址
    output wire[3:0]  ext_ram_be_n,         //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire       ext_ram_ce_n,         //ExtRAM片选，低有效
    output wire       ext_ram_oe_n,         //ExtRAM读使能，低有效
    output wire       ext_ram_we_n,         //ExtRAM写使能，低有效

    //直连串口信号
    output wire txd,  //直连串口发送端
    input  wire rxd,  //直连串口接收端

    //Flash存储器信号，参考 JS28F640 芯片手册
    output wire [22:0]flash_a,      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  wire [15:0]flash_d,      //Flash数据
    output wire flash_rp_n,         //Flash复位信号，低有效
    output wire flash_vpen,         //Flash写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,         //Flash片选信号，低有效
    output wire flash_oe_n,         //Flash读使能信号，低有效
    output wire flash_we_n,         //Flash写使能信号，低有效
    output wire flash_byte_n,       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    //图像输出信号
    output wire[2:0] video_red,         //红色像素，3位
    output wire[2:0] video_green,       //绿色像素，3位
    output wire[1:0] video_blue,        //蓝色像素，2位
    output wire      video_hsync,       //行同步（水平同步）信号
    output wire      video_vsync,       //场同步（垂直同步）信号
    output wire      video_clk,         //像素时钟输出
    output wire      video_de           //行数据有效信号，用于区分消隐区
);

/* =========== Demo code begin =========== */

// PLL分频示例
wire locked, clk_10M, clk_20M;
pll_example clock_gen 
(
    // Clock in ports
    .clk_in1(clk_50M),  // 外部时钟输入
    // Clock out ports
    .clk_out1(clk_10M), // 时钟输出1，频率在IP配置界面中设置
    .clk_out2(clk_20M), // 时钟输出2，频率在IP配置界面中设置
    // Status and control signals
    .reset(reset_btn), // PLL复位输入
    .locked(locked)    // PLL锁定指示输出，"1"表示时钟稳定，
                        // 后级电路复位信号应当由它生成（见下）
);

// reg reset_of_clk10M;
// // 异步复位，同步释放，将locked信号转为后级电路的复位reset_of_clk10M，高电平有效
// always@(posedge clk_20M or negedge locked) begin
//     if(~locked) begin
//         reset_of_clk10M <= 1'b1;
//     end else begin
//         reset_of_clk10M <= 1'b0;
//     end       
// end

wire my_clk;
wire my_reset;
assign my_clk   = clk_50M;
assign my_reset = reset_btn;
// reset_btn高电平有效

//cpu inst sram
wire        cpu_inst_en     ;
wire [3 :0] cpu_inst_we     ;
wire [31:0] cpu_inst_addr   ;
wire [31:0] cpu_inst_wdata  ;
wire [31:0] cpu_inst_rdata_tmp  ;
wire [31:0] cpu_inst_rdata  ;
//cpu data sram             
wire        cpu_data_en     ;
wire [3 :0] cpu_data_we     ;
wire [31:0] cpu_data_addr   ;
wire [31:0] cpu_data_wdata  ;
wire [31:0] cpu_data_rdata_tmp  ;
wire [31:0] cpu_data_rdata  ;


// wire        ext_ram_ce_n_tmp;


wire[31:0] ext_ram_data_tmp;
wire[31:0] base_ram_data_tmp;
wire[19:0] base_ram_addr_tmp;
wire[ 3:0] base_ram_be_n_tmp;
wire       base_ram_ce_n_tmp;
wire       base_ram_oe_n_tmp;
wire       base_ram_we_n_tmp;
// wire       is_base         ;


// // inst ram <-> base ram
// conver_ram inst_conver_ram(
//     .clk              (my_clk         ),
//     .resetn           (my_reset ),

//     .cpu_sram_en      (cpu_inst_en   ),
//     .cpu_sram_we      (cpu_inst_we   ),
//     .cpu_sram_addr    (cpu_inst_addr ),
//     .cpu_sram_wdata   (cpu_inst_wdata),

//     .cpu_sram_rdata   (cpu_inst_rdata),

//     .ram_data         (base_ram_data_tmp ),
//     .ram_addr         (base_ram_addr_tmp ),
//     .ram_be_n         (base_ram_be_n_tmp ),
//     .ram_ce_n         (base_ram_ce_n_tmp ),
//     .ram_oe_n         (base_ram_oe_n_tmp ),
//     .ram_we_n         (base_ram_we_n_tmp )
// );
// // data ram <-> ext ram
// data_conver_ram my_data_conver_ram(
//     .clk              (my_clk          ),
//     .resetn           (my_reset  ),

//     // .rxd(rxd),
//     // .txd(txd),

//     .cpu_sram_en      (cpu_data_en   ),
//     .cpu_sram_we      (cpu_data_we   ),
//     .cpu_sram_addr    (cpu_data_addr ),
//     .cpu_sram_wdata   (cpu_data_wdata),

//     .cpu_sram_rdata   (cpu_data_rdata),

//     .ram_data         (ext_ram_data_tmp ),
//     .ram_addr         (ext_ram_addr ),
//     .ram_be_n         (ext_ram_be_n ),
//     .ram_ce_n         (ext_ram_ce_n ),
//     .ram_oe_n         (ext_ram_oe_n ),
//     .ram_we_n         (ext_ram_we_n ),

//     .is_base          (is_base      )
// );

// assign ext_ram_data_tmp = is_base ? base_ram_data : ext_ram_data;

// assign base_ram_data = is_base ? ext_ram_data : base_ram_data_tmp;
// assign base_ram_addr = is_base ? ext_ram_addr : base_ram_addr_tmp;
// assign base_ram_be_n = is_base ? ext_ram_be_n : base_ram_be_n_tmp;
// assign base_ram_ce_n = is_base ? 1'b0         : base_ram_ce_n_tmp;
// assign base_ram_oe_n = is_base ? ext_ram_oe_n : base_ram_oe_n_tmp;
// assign base_ram_we_n = is_base ? ext_ram_we_n : base_ram_we_n_tmp;

RAM  u_RAM (
    .clk                        (my_clk             ),
    .resetn                     (my_reset           ),

    .cpu_inst_en                (cpu_inst_en        ),
    .cpu_inst_we                (cpu_inst_we        ),
    .cpu_inst_addr              (cpu_inst_addr      ),
    .cpu_inst_wdata             (cpu_inst_wdata     ),

    .cpu_data_en                (cpu_data_en        ),
    .cpu_data_we                (cpu_data_we        ),
    .cpu_data_addr              (cpu_data_addr      ),
    .cpu_data_wdata             (cpu_data_wdata     ),

    .cpu_inst_rdata             (cpu_inst_rdata     ),
    .cpu_data_rdata             (cpu_data_rdata     ),

    .base_ram_addr              (base_ram_addr      ),
    .base_ram_be_n              (base_ram_be_n      ),
    .base_ram_ce_n              (base_ram_ce_n      ),
    .base_ram_oe_n              (base_ram_oe_n      ),
    .base_ram_we_n              (base_ram_we_n      ),

    .ext_ram_addr               (ext_ram_addr       ),
    .ext_ram_be_n               (ext_ram_be_n       ),
    .ext_ram_ce_n               (ext_ram_ce_n       ),
    .ext_ram_oe_n               (ext_ram_oe_n       ),
    .ext_ram_we_n               (ext_ram_we_n       ),

    .base_ram_data              (base_ram_data      ),
    .ext_ram_data               (ext_ram_data       )
);

//cpu
mycpu_top u_mycpu_top(
    .clk              (my_clk          ),
    .resetn           (~my_reset  ),  //low active
    // inst
    .inst_sram_en     (cpu_inst_en   ),
    .inst_sram_we     (cpu_inst_we   ),
    .inst_sram_addr   (cpu_inst_addr ),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_rdata  (cpu_inst_rdata),
    // data                                 
    .data_sram_en     (cpu_data_en   ),
    .data_sram_we     (cpu_data_we   ),
    .data_sram_addr   (cpu_data_addr ),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_rdata  (cpu_data_rdata)

    // //debug
    // .debug_wb_pc      (debug_wb_pc      ),
    // .debug_wb_rf_we   (debug_wb_rf_we   ),
    // .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    // .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
















// 7段数码管译码器演示，将number用16进制显示在数码管上面
wire[7:0] number;
SEG7_LUT segL(.oSEG1(dpy0), .iDIG(number[3:0])); //dpy0是低位数码管
SEG7_LUT segH(.oSEG1(dpy1), .iDIG(number[7:4])); //dpy1是高位数码管

reg[15:0] led_bits;
assign leds = led_bits;

always@(posedge clock_btn or posedge reset_btn) begin
    if(reset_btn)begin //复位按下，设置LED为初始值
        led_bits <= 16'h1;
    end
    else begin //每次按下时钟按钮，LED循环左移
        led_bits <= {led_bits[14:0],led_bits[15]};
    end
end

//图像输出演示，分辨率800x600@75Hz，像素时钟为50MHz
wire [11:0] hdata;
assign video_red = hdata < 266 ? 3'b111 : 0; //红色竖条
assign video_green = hdata < 532 && hdata >= 266 ? 3'b111 : 0; //绿色竖条
assign video_blue = hdata >= 532 ? 2'b11 : 0; //蓝色竖条
assign video_clk = my_clk;
vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
    .clk(my_clk), 
    .hdata(hdata), //横坐标
    .vdata(),      //纵坐标
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);
/* =========== Demo code end =========== */

endmodule
