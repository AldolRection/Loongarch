module PIPELINE_stop (
    input       clk         ,
    input       reset       ,

    input       id_stop     ,
    // input       mem_begin   ,

    output reg  if_stop
);

parameter D00 = 2'b00;
parameter D01 = 2'b01;
parameter D02 = 2'b10;
parameter D03 = 2'b11;

reg     [1:0]   st_cur;

always @(posedge clk or negedge reset) begin
    if (reset) begin
        st_cur <= 2'b00;
        if_stop <= 1'b0;
    end else begin
        if (id_stop) begin
            st_cur <= 2'b00;
            if_stop <= 1'b1;
        end else begin
            case (st_cur)
                D00: begin
                    st_cur <= D01;
                end
                D01: begin
                    st_cur <= D02;
                end
                D02: begin
                    st_cur <= D03;
                end
                D03: begin
                    st_cur <= D00;
                    if_stop <= 1'b0;
                end
                default: begin
                    st_cur <= 2'b00;
                    if_stop <= 1'b0;
                end 
            endcase
        end
    end
end

    
endmodule