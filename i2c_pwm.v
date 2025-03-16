`timescale 1ns / 1ps

module i2c_slave_pwm (
    inout wire sda,    // I2C Data Line
    inout wire scl,    // I2C Clock Line
    output wire pwm_out // PWM Output Signal
);

// Slave Address (Change as Needed)
localparam ADDRESS = 7'b0101010;  

// I2C States
localparam READ_ADDR = 0;
localparam SEND_ACK = 1;
localparam READ_DATA = 2;
localparam UPDATE_PWM = 3;
localparam SEND_ACK2 = 4;

reg [7:0] addr;
reg [7:0] counter;
reg [7:0] state = 0;
reg [7:0] received_data = 0; // Stores received data (PWM duty cycle)
reg sda_out = 0;
reg start = 0;
reg write_enable = 0;

assign sda = (write_enable == 1) ? sda_out : 1'bz;

// Detect Start Condition
always @(negedge sda) begin
    if ((start == 0) && (scl == 1)) begin
        start <= 1;    
        counter <= 7;
    end
end

// Detect Stop Condition
always @(posedge sda) begin
    if ((start == 1) && (scl == 1)) begin
        state <= READ_ADDR;
        start <= 0;
        write_enable <= 0;
    end
end

// I2C State Machine
always @(posedge scl) begin
    if (start == 1) begin
        case(state)
            READ_ADDR: begin
                addr[counter] <= sda;
                if(counter == 0) state <= SEND_ACK;
                else counter <= counter - 1;                    
            end
            
            SEND_ACK: begin
                if(addr[7:1] == ADDRESS) begin
                    counter <= 7;
                    if(addr[0] == 0) state <= READ_DATA; // Master wants to write data
                end
            end

            READ_DATA: begin
                received_data[counter] <= sda; // Store received bits
                if(counter == 0) state <= UPDATE_PWM;
                else counter <= counter - 1;
            end

            UPDATE_PWM: begin
                state <= SEND_ACK2; // Move to ACK state after updating PWM
            end
            
            SEND_ACK2: begin
                state <= READ_ADDR;                    
            end
        endcase
    end
end

// SDA Control
always @(negedge scl) begin
    case(state)
        READ_ADDR: begin
            write_enable <= 0;            
        end
        
        SEND_ACK: begin
            sda_out <= 0;
            write_enable <= 1;    
        end
        
        READ_DATA: begin
            write_enable <= 0;
        end

        SEND_ACK2: begin
            sda_out <= 0;
            write_enable <= 1;
        end
    endcase
end

// PWM Generator Instance
pwm_generator pwm_inst (
    .clk(scl),  // Use I2C clock as base clock
    .duty_cycle(received_data), // Received data determines PWM duty cycle
    .pwm_out(pwm_out)
);

endmodule
module pwm_generator (
    input wire clk,
    input wire [7:0] duty_cycle, // 0-255 mapped to 0-100%
    output reg pwm_out
);

reg [7:0] counter = 0;

always @(posedge clk) begin
    counter <= counter + 1;
    pwm_out <= (counter < duty_cycle) ? 1 : 0; // Duty cycle comparison
end

endmodule
