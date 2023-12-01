`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_we  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,

    input         if_stop
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         pre_if_ready_go;

wire         br_stall;
wire         br_taken;
wire [ 31:0] br_target;

assign {br_stall, br_taken, br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = ~reset;
assign pre_if_ready_go = ~br_stall;


// because after sending fs_pc to ds, the seq_pc = fs_pc + 4 immediately
// Actually, the seq_pc is just a delay slot instruction
// if we use inst pc, here need to -4, it's more troublesome
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : (if_stop ? nextpc : seq_pc); 

// IF stage
// if_stop, high level is valid
assign fs_ready_go    = ~br_taken & ~if_stop;   // if taken is valid, if stage block
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;     
assign fs_to_ds_valid =  fs_valid && fs_ready_go;   
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;    
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h7FFFFFFC;     //1bfffffc, trick: to make nextpc be 0x1c000000 during reset 
        //           80000000 7FFFFFFC
        //           803FFFFF
    end else if (if_stop) begin
        fs_pc <= nextpc;
    end else if (to_fs_valid && (fs_allowin || br_taken)) begin
        // if taken is valid, to skip the delay slot instruction, next_pc should be the instruction after the jump inst
        fs_pc <= nextpc;
    end
end

// if taken is valid and if stage is block, get the instruction after the jump inst
assign inst_sram_en    = if_stop ? inst_sram_en : (to_fs_valid && (fs_allowin || br_taken));
assign inst_sram_we    = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

endmodule
