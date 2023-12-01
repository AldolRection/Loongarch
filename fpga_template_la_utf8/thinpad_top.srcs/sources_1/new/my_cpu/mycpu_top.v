`include "mycpu.h"

module mycpu_top(
    input         clk               ,
    input         resetn            ,
    // inst sram interface          
    output        inst_sram_en      ,
    output        inst_sram_oe      ,
    output [ 3:0] inst_sram_we      ,
    output [31:0] inst_sram_addr    ,
    output [31:0] inst_sram_wdata   ,
    input  [31:0] inst_sram_rdata   ,

    // data sram interface          
    output        data_sram_en      ,
    output        data_sram_oe      ,
    output [ 3:0] data_sram_we      ,
    output [31:0] data_sram_addr    ,
    output [31:0] data_sram_wdata   ,
    input  [31:0] data_sram_rdata   ,

    // trace debug interface        
    output [31:0] debug_wb_pc       ,
    output [ 3:0] debug_wb_rf_we    ,
    output [ 4:0] debug_wb_rf_wnum  ,
    output [31:0] debug_wb_rf_wdata 
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;

wire [4:0]          es_to_ds_dest;
wire [4:0]          ms_to_ds_dest;
wire [4:0]          ws_to_ds_dest;

wire                es_to_ds_load_op;

wire [31:0]         es_to_ds_result;
wire [31:0]         ms_to_ds_result;
wire [31:0]         ws_to_ds_result;

wire if_stop;
wire id_stop;

// PIPELINE_stop
PIPELINE_stop PIPELINE_stop(
    .clk            (clk            ),
    .reset          (reset          ),
    .if_stop        (if_stop        ),
    .id_stop        (id_stop        )
);
// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_we   (inst_sram_we  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),

    .if_stop        (if_stop        )
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ), 
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),

    // block
    .es_to_ds_dest  (es_to_ds_dest  ),
    .ms_to_ds_dest  (ms_to_ds_dest  ),
    .ws_to_ds_dest  (ws_to_ds_dest  ),
    .es_to_ds_load_op(es_to_ds_load_op),


    .es_to_ds_result(es_to_ds_result),
    .ms_to_ds_result(ms_to_ds_result),
    .ws_to_ds_result(ws_to_ds_result),

    .id_stop        (id_stop        )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_we   (data_sram_we   ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),

    // block
    .es_to_ds_dest  (es_to_ds_dest  ),
    .es_to_ds_load_op(es_to_ds_load_op),

    .es_to_ds_result(es_to_ds_result)
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),

    // block
    .ms_to_ds_dest  (ms_to_ds_dest  ),

    .ms_to_ds_result(ms_to_ds_result)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    // block
    .ws_to_ds_dest  (ws_to_ds_dest  ),

    .ws_to_ds_result(ws_to_ds_result)
);



endmodule
