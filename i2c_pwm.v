i2c-module i2c_pwm (
    input wire clk,    // System clock
    input wire SCL,    // I2C clock
    inout wire SDA,    // I2C data
    input wire RST,    // Reset
    output reg pwm_out // PWM output
);

    parameter [6:0] device_address = 7'h55;
    
    reg [7:0] duty_cycle;
    reg [7:0] counter;
    
    reg [7:0] input_shift;
    reg [3:0] bit_counter;
    reg [2:0] state;
    reg output_control;
    reg master_ack;
    reg start_detect, stop_detect;
    reg start_resetter, stop_resetter;
    reg [7:0] index_pointer;
    
    parameter [2:0] STATE_IDLE = 3'h0,
                    STATE_DEV_ADDR = 3'h1,
                    STATE_IDX_PTR = 3'h2,
                    STATE_WRITE = 3'h3;
    
    wire start_rst = RST | start_resetter;
    wire stop_rst = RST | stop_resetter;
    wire lsb_bit = (bit_counter == 4'h7) && !start_detect;
    wire ack_bit = (bit_counter == 4'h8) && !start_detect;
    wire address_detect = (input_shift[7:1] == device_address);
    wire write_strobe = (state == STATE_WRITE) && ack_bit;
    assign SDA = output_control ? 1'bz : 1'b0;

    // Start detection
    always @(posedge start_rst or negedge SDA)
        if (start_rst) start_detect <= 1'b0;
        else start_detect <= SCL;

    always @(posedge RST or posedge SCL)
        if (RST) start_resetter <= 1'b0;
        else start_resetter <= start_detect;
    
    // Stop detection
    always @(posedge stop_rst or posedge SDA)
        if (stop_rst) stop_detect <= 1'b0;
        else stop_detect <= SCL;
    
    always @(posedge RST or posedge SCL)
        if (RST) stop_resetter <= 1'b0;
        else stop_resetter <= stop_detect;
    
    // I2C Shift Register
    always @(negedge SCL)
        if (ack_bit || start_detect) bit_counter <= 4'h0;
        else bit_counter <= bit_counter + 4'h1;
    
    always @(posedge SCL)
        if (!ack_bit) input_shift <= {input_shift[6:0], SDA};
    
    always @(posedge SCL)
        if (ack_bit) master_ack <= ~SDA;
    
    // State Machine
    always @(posedge RST or negedge SCL)
        if (RST) state <= STATE_IDLE;
        else if (start_detect) state <= STATE_DEV_ADDR;
        else if (ack_bit)
            case (state)
                STATE_IDLE: state <= STATE_IDLE;
                STATE_DEV_ADDR:
                    if (!address_detect) state <= STATE_IDLE;
                    else state <= STATE_IDX_PTR;
                STATE_IDX_PTR: state <= STATE_WRITE;
                STATE_WRITE: state <= STATE_WRITE;
            endcase
        else if (stop_detect) state <= STATE_IDLE;
    
    // Index Pointer
    always @(posedge RST or negedge SCL)
        if (RST) index_pointer <= 8'h00;
        else if (stop_detect) index_pointer <= 8'h00;
        else if (ack_bit)
            if (state == STATE_IDX_PTR) index_pointer <= input_shift;
            else index_pointer <= index_pointer + 8'h01;
    
    // Write to PWM Duty Cycle Register
    always @(posedge RST or negedge SCL)
        if (RST) duty_cycle <= 8'h00;
        else if (write_strobe && (index_pointer == 8'h00)) duty_cycle <= input_shift;
    
    // PWM Generation
    always @(posedge clk or posedge RST)
        if (RST) begin
            counter <= 8'h00;
            pwm_out <= 1'b0;
        end else begin
            counter <= counter + 8'h01;
            pwm_out <= (counter < duty_cycle) ? 1'b1 : 1'b0;
        end
endmodule