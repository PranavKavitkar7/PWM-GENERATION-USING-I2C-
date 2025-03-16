`timescale 1ns / 1ps

module tb_i2c_slave_pwm();

reg sda, scl;
wire pwm_out;
reg [7:0] test_data = 8'b01100100; // Test: Set duty cycle to 100 (out of 255)

i2c_slave_pwm dut (
    .sda(sda),
    .scl(scl),
    .pwm_out(pwm_out)
);

initial begin
    // Initialize signals
    sda = 1;
    scl = 1;
    #10;

    // Simulate Start Condition (SDA goes low while SCL is high)
    sda = 0;
    #5;
    scl = 0;
    #5;
    
    // Send Slave Address (7-bit) + Write (0)
    send_byte({7'b0101010, 1'b0});
    
    // Send Data Byte (PWM Duty Cycle)
    send_byte(test_data);
    
    // Simulate Stop Condition (SDA goes high while SCL is high)
    scl = 1;
    #5;
    sda = 1;
    
    #100;
    $stop;
end

// Task to send a byte over I2C
task send_byte(input [7:0] byte);
    integer i;
    for (i = 7; i >= 0; i = i - 1) begin
        scl = 0;
        #5;
        sda = byte[i];
        #5;
        scl = 1;
        #5;
    end
endtask

endmodule
