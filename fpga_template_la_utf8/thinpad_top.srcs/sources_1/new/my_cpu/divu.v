module divu (
    input                clk,
    input                reset,
    input        [31:0]  src1,
    input        [31:0]  src2,
    input                op_div,
    output   wire    [63:0]  di_result,
    output   wire            complete
);

// DIV result
reg              s_axis_divisor_tvalid;
wire             s_axis_divisor_tready;
wire     [31:0]  s_axis_divisor_tdata;
reg              s_axis_dividend_tvalid;
wire             s_axis_dividend_tready;
wire     [31:0]  s_axis_dividend_tdata;
wire             m_axis_dout_tvalid;
wire     [63:0]  m_axis_dout_tdata;

mydivu mydivuu (
    .aclk(clk),
    .s_axis_divisor_tvalid  (s_axis_divisor_tvalid),
    .s_axis_divisor_tready  (s_axis_divisor_tready),
    .s_axis_divisor_tdata   (s_axis_divisor_tdata),

    .s_axis_dividend_tvalid (s_axis_dividend_tvalid),
    .s_axis_dividend_tready (s_axis_dividend_tready),
    .s_axis_dividend_tdata  (s_axis_dividend_tdata),

    .m_axis_dout_tvalid     (m_axis_dout_tvalid),
    .m_axis_dout_tdata      (m_axis_dout_tdata)
);

assign s_axis_divisor_tdata  = src2;
assign s_axis_dividend_tdata = src1;

parameter free      = 2'b00;
parameter load_data = 2'b01;
parameter begin_div = 2'b10;
// parameter end_div   = 2'b11;

reg [1:0]            st_cur  ;

always @(posedge clk or negedge reset) begin
    if (reset) begin
        st_cur <= free;
        s_axis_divisor_tvalid  <= 1'b0;
        s_axis_dividend_tvalid <= 1'b0;
    end else if (op_div) begin
        case (st_cur)
            free: 
            case (op_div)
                1'b1: begin
                    st_cur <= load_data;
                    s_axis_divisor_tvalid  <= 1'b1;
                    s_axis_dividend_tvalid <= 1'b1;
                end            
                default: st_cur <= free;
            endcase

            load_data:
            case (s_axis_divisor_tready & s_axis_dividend_tready)
                1'b1: begin
                    st_cur <= begin_div;
                    s_axis_divisor_tvalid  <= 1'b0;
                    s_axis_dividend_tvalid <= 1'b0;
                end
                default: st_cur <= load_data;
            endcase

            begin_div:
            case (m_axis_dout_tvalid)
                1'b1: begin
                    st_cur <= free;
                end
                default: st_cur <= begin_div;
            endcase

            // end_div: begin
            //     st_cur <= free;
            // end 
            default: st_cur <= free;
        endcase
    end
end

assign complete = m_axis_dout_tvalid;
assign di_result = m_axis_dout_tdata;
// assign div64_result = complete? m_axis_dout_tdata : 64'bz;

endmodule
