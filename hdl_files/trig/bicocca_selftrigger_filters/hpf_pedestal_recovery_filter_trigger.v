`timescale 1ns / 10ps
//////////////////////////////////////////////////////////////////////////////////
// University: UNIMIB 
// Engineer: Esteban Cristaldo, MSc
//
// Create Date: July 14, 2022, 11:53:42 AM
// Design Name: filtering_and_selftrigger
// Module Name: hpf_pedestal_recovery_filter_trigger.v
// Project Name: selftrigger@bicocca
// Target Devices: DAPHNE V2
//
//////////////////////////////////////////////////////////////////////////////////
module hpf_pedestal_recovery_filter_trigger(
	input wire clk,
	input wire reset,
	input wire enable,
    input wire afe_comp_enable,
    input wire invert_enable,
    //input wire signed [13:0] threshold_value,
    input wire [41:0] threshold_xc,
    input wire [1:0] output_selector,
    output wire signed [15:0] baseline,
	input wire signed [15:0] x,
    output wire trigger_output,
	output wire signed [15:0] y1,
    output wire signed [15:0] y2
);
	
	wire signed [15:0] hpf_out, hpf_out_aux, hpf_out_xcorr;
    wire signed [15:0] movmean_out;
    wire signed [13:0] movmean_out_14;
	wire signed [15:0] x_i, x_delayed;
    wire signed [15:0] baseline_aux;
    //wire signed [15:0] w_resta_out [4:0][7:0];
    wire signed [15:0] w_out;
	wire signed [15:0] resta_out, lpf_out, cfd_out;
	wire signed [15:0] suma_out;
    wire tm_output_selector;
    wire internal_afe_comp_enable;

    wire triggered_xc;
    wire signed [27:0] xcorr_calc;

    //(* dont_touch = "true" *) reg signed [13:0] threshold_level;

    //initial begin 
    //    threshold_level <= $signed(256); // Same as DEFAULT_THRESHOLD
    //end 

    //always @(posedge clk) begin 
    //    if(reset) begin
    //       threshold_level <= $signed(256); // Same as DEFAULT_THRESHOLD
    //    end else if (enable) begin 
    //       threshold_level <= $signed(threshold_value);
    //    end
    //end
    

    k_low_pass_filter lpf(
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .x(x_i),
        .y(lpf_out)
    );

    IIRFilter_afe_integrator_optimized hpf(
        .clk(clk),
        .reset(reset),
        .enable(internal_afe_comp_enable),
        .x(resta_out),
        .y(hpf_out)
    );

    //IIRfilter_movmean25_cfd_trigger mov_mean_cfd(
    //    .clk(clk),
    //    .reset(reset),
    //    .enable(enable),
    //    .output_selector(tm_output_selector),
    //    .threshold(threshold_level),
    //    .x(hpf_out),
    //    .trigger(trigger_output),
    //    .y(movmean_out)
    //);

    moving_integrator_filter movmean(
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .x(hpf_out_xcorr),
        .y(movmean_out),
        .x_delayed(x_delayed)
        );

    trig_xc matching_trigger(
        .reset(reset),
        .clock(clk),
        .enable(enable),
        .din(x_delayed[13:0]),
        .threshold(threshold_xc),
        .xcorr_calc(xcorr_calc),
        .triggered(triggered_xc)
    );

    Configurable_CFD cfd(
        .clock(clk),
        .reset(reset),
        .enable(enable),
        .trigger_threshold(triggered_xc),
        .config_delay(5'b11010),
        .config_sign(1'b0),
        .din(xcorr_calc),
        .trigger(trigger_output)
    );

    assign resta_out =  (enable==0) ?   x_i : 
                        (enable==1) ?   (x_i - lpf_out) : 
                        16'bx; 
    
    assign suma_out = (enable==0) ?   hpf_out : 
                      (enable==1) ?   (hpf_out + lpf_out) : 
                      16'bx;

    assign hpf_out_aux = (invert_enable==0) ?   hpf_out :
                         (invert_enable==1) ?   (~(hpf_out) + 16'b0000000000000001) :
                         16'b0000000000000000;

    assign hpf_out_xcorr = (invert_enable==1) ?   hpf_out :
                           (invert_enable==0) ?   (~(hpf_out) + 16'b0000000000000001) :
                           16'b0000000000000000;
                    
    assign baseline_aux = (invert_enable==0) ?   lpf_out :
                          (invert_enable==1) ?   (16'b0100000000000000 - lpf_out) :
                          16'bx;

    assign w_out = (output_selector == 2'b00) ?   suma_out : 
                   (output_selector == 2'b01) ?   baseline_aux + hpf_out_aux : //lpf_out + movmean_out : //movmean
                   (output_selector == 2'b10) ?   lpf_out + xcorr_calc[15:0] : //+ xcorr_calc : //cfd_out : //movmean cfd
                   (output_selector == 2'b11) ?   x_i :
                   16'bx;
    // Daniel:
    // En el selector w_out podriamos incluir la inversión de la señal de salida que va al DAQ porque presiento que nos lo 
    // solicitarán. Podríamos reemplazar "lpf_out + movmean_out" por "2**14 - suma_out".
    // 2**14 - suma_out = 2**14 - lpf_out - hpf_out.
    // Inversion del pedestal: 2**14 - lpf_out.
    // Inversion de la señal: - hpf_out.

    assign x_i = x;
    assign y1 = w_out; //Esta señal va al DAQ.
    assign y2 = hpf_out_xcorr; // Esta señal va al Selftrigger TP. Aqui podriamos colocar la logica
                               // condicional de la inversión segun el estado invert_enable, similar al condicional suma_out. 
                               // La inversion es directa porque la señal esta centrada en cero.
    assign baseline = baseline_aux; //lpf_out; // Aqui también habrá que modificar el baseline según la condicion invert_enable.
    assign internal_afe_comp_enable = (enable & afe_comp_enable);
    //assign movmean_out = $signed(movmean_out_14);
	
    assign tm_output_selector = (output_selector == 2'b00) ?   1'b0 : //hpf 
                                (output_selector == 2'b01) ?   1'b0 : //movmean
                                (output_selector == 2'b10) ?   1'b1 : //movmean cfd
                                (output_selector == 2'b11) ?   1'b0 : //unfiltered
                                 1'bx;

endmodule