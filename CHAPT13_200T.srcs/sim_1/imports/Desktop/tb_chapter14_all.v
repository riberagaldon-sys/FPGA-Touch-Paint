`timescale 1ns/1fs

// Teaching manual Chapter 14 -> chapter13_paint_200t.xpr.
// Simulation top: tb_chapter14_all. Run 3 ms; expect CH14 PASS at 2.45 ms.
// Actual hierarchy: dut (game_system_5slot) -> u_game5_paint.
// Screenshot signals below are read-only aliases at the testbench root.
// Original 200x120x4-bit RAM, 4x enlargement and 51.2 MHz clock are retained.
// Only normal page, event, pointer and pixel-coordinate inputs are driven.
// No force, register deposits, RTL edits or RAM-size/clock overrides.
// The scoreboard checks all 24000 addresses on every completed clear,
// synchronous read-before-write, interpolation, palette and clipped eraser.
// Pointer inputs are the public application interface: this is not an
// I2C/PS2/MMCM/LCD pin timing test, synthesis report or board measurement.
// read_pixel_x=pixel_x+1 is the actual original prefetch path. RGB here is
// the slot's combinational output, before the top-level LCD RGB register.
// ST_CLEAR_DONE lasts one clock; it does not wait for a frame_start input.
// RAM is intentionally not initialized by the testbench: page-entry clear
// writes all 24000 cells through the original RAM port.
// No $finish/$stop: keep the Vivado waveform window open for screenshots.
//
// Figure 14-1: 499.80..502.80 us, release unlocking and the first red cell.
//   pointer_down, pointer_armed, stroke_write, ram_we, ram_waddr/data,
//   canvas_raddr/data, draw_count. Address 1405; data 0->2; count 0->1.
//   Holding the entry pointer until 500 us must not leave a mark.
// Figure 14-2(a): 699.90..700.45 us, manual clear starts from address 0.
// Figure 14-2(b): 1168.55..1170.80 us, last address 23999 and first new mark.
//   state_live, pointer_down, clear_addr, stroke_write, ram_we,
//   ram_waddr/data, draw_count. State 3->4->0, then draw at address 2020.
//   States: 0 IDLE, 1 DRAW, 2 ERASE, 3 CLEAR, 4 CLEAR_DONE.
//   Unsigned Decimal: addresses, coordinates, counters, state/color index.
//   Binary: one-bit enables; Hexadecimal: RAM data and pixel_rgb.

module tb_chapter14_all;
    reg clk = 1'b0;
    always #9.765625 clk = ~clk;
    reg rst_n = 1'b0;
    reg [2:0] ui_state_control = 3'd1;
    reg [2:0] ui_state_frame = 3'd1;
    reg event_up = 1'b0;
    reg event_down = 1'b0;
    reg event_left = 1'b0;
    reg event_right = 1'b0;
    reg event_ok = 1'b0;
    reg event_back = 1'b0;
    reg event_pause = 1'b0;
    reg [10:0] pointer_x = 11'd132;
    reg [9:0] pointer_y = 10'd128;
    reg pointer_down = 1'b1;
    reg [10:0] pixel_x = 11'd132;
    reg [9:0] pixel_y = 10'd128;
    wire pixel_on;
    wire [23:0] pixel_rgb;
    wire [15:0] score;
    wire [3:0] game_state;
    wire exit_request;

    game_system_5slot dut (
        .clk(clk), .rst_n(rst_n),
        .ui_state_control(ui_state_control), .ui_state_frame(ui_state_frame),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause), .game_tick(1'b0), .tick_1s(1'b0),
        .pointer_x(pointer_x), .pointer_y(pointer_y), .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .pixel_on(pixel_on),
        .pixel_rgb(pixel_rgb), .score(score), .game_state(game_state),
        .exit_request(exit_request)
    );

    wire [4:0] enable = dut.enable;
    wire game_enable = enable[4];
    wire [2:0] state_live = dut.u_game5_paint.state_live;
    wire [3:0] selected_color = dut.u_game5_paint.selected_color;
    wire erase_mode = dut.u_game5_paint.erase_mode;
    wire pointer_armed = dut.u_game5_paint.pointer_armed;
    wire pointer_press = dut.u_game5_paint.pointer_press;
    wire pointer_in_canvas = dut.u_game5_paint.pointer_in_canvas;
    wire [7:0] pointer_canvas_x = dut.u_game5_paint.pointer_canvas_x;
    wire [6:0] pointer_canvas_y = dut.u_game5_paint.pointer_canvas_y;
    wire pointer_gesture_guard = dut.u_game5_paint.pointer_gesture_guard;
    wire stroke_active = dut.u_game5_paint.stroke_active;
    wire stroke_write = dut.u_game5_paint.stroke_write;
    wire [7:0] stroke_x = dut.u_game5_paint.stroke_x;
    wire [6:0] stroke_y = dut.u_game5_paint.stroke_y;
    wire [7:0] stroke_target_x = dut.u_game5_paint.stroke_target_x;
    wire [6:0] stroke_target_y = dut.u_game5_paint.stroke_target_y;
    wire [14:0] stroke_addr = dut.u_game5_paint.stroke_addr;
    wire [3:0] erase_brush_phase = dut.u_game5_paint.erase_brush_phase;
    wire [14:0] clear_addr = dut.u_game5_paint.clear_addr;
    wire [15:0] draw_count = dut.u_game5_paint.draw_count;
    wire ram_we = dut.u_game5_paint.ram_we;
    wire [14:0] ram_waddr = dut.u_game5_paint.ram_waddr;
    wire [3:0] ram_wdata = dut.u_game5_paint.ram_wdata;
    wire [10:0] read_pixel_x = dut.u_game5_paint.read_pixel_x;
    wire read_pixel_in_canvas = dut.u_game5_paint.read_pixel_in_canvas;
    wire [14:0] canvas_raddr = dut.u_game5_paint.canvas_raddr;
    wire [3:0] canvas_rdata = dut.u_game5_paint.canvas_rdata;
    wire [3:0] cell_1405 = dut.u_game5_paint.canvas_mem[1405];
    wire [3:0] cell_2020 = dut.u_game5_paint.canvas_mem[2020];
    wire [3:0] cell_0 = dut.u_game5_paint.canvas_mem[0];
    wire [3:0] cell_23999 = dut.u_game5_paint.canvas_mem[23999];

    integer case_id = 0;
    integer errors = 0;
    integer completed_clears = 0;
    integer clear_steps = 0;
    integer total_clear_writes = 0;
    integer draw_writes = 0;
    integer erase_writes = 0;
    integer read_checks = 0;
    integer palette_tests = 0;
    integer boundary_tests = 0;
    integer interpolation_tests = 0;
    integer guard_tests = 0;
    integer i, j, old_count;
    reg checks_done = 1'b0;
    reg checks_pass = 1'b0;
    reg previous_clear = 1'b0;
    reg [3:0] reference_mem [0:23999];
    reg [3:0] expected_read;
    reg sampled_write;
    integer sampled_addr, sampled_raddr, prefetch_x;
    reg [3:0] sampled_data;

    task check;
        input condition;
        input [767:0] message;
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("CH14 FAIL at %0.6f us: %0s", $realtime/1000.0, message);
            end
        end
    endtask

    task at_ns;
        input integer target_ns;
        real remaining;
        begin
            remaining = target_ns - $realtime;
            if (remaining > 0) #(remaining);
            @(negedge clk);
        end
    endtask

    // Mask bits: Up, Down, Left, Right, OK, Back, Pause.
    task pulse;
        input [6:0] mask;
        begin
            @(negedge clk);
            event_up=mask[0]; event_down=mask[1]; event_left=mask[2];
            event_right=mask[3]; event_ok=mask[4]; event_back=mask[5];
            event_pause=mask[6];
            @(negedge clk);
            event_up=0; event_down=0; event_left=0; event_right=0;
            event_ok=0; event_back=0; event_pause=0;
            @(negedge clk);
        end
    endtask

    task release_pointer;
        begin
            @(negedge clk); pointer_down=1'b0;
            wait (stroke_active == 1'b0);
            repeat (2) @(negedge clk);
        end
    endtask

    task click_at;
        input integer x;
        input integer y;
        begin
            @(negedge clk);
            pointer_x=x; pointer_y=y; pointer_down=1'b1;
            repeat (3) @(negedge clk);
            pointer_down=1'b0;
            wait (stroke_active == 1'b0);
            repeat (2) @(negedge clk);
        end
    endtask

    task select_palette;
        input integer color_index;
        begin
            click_at(30 + 62*color_index,30);
            check(selected_color == color_index && !erase_mode,
                  "toolbar palette selection or draw-mode restore failed");
            palette_tests=palette_tests+1;
        end
    endtask

    task verify_zero_canvas;
        begin
            for (j=0; j<24000; j=j+1)
                check(dut.u_game5_paint.canvas_mem[j] === 4'h0,
                      "a completed clear left a nonzero/uninitialized cell");
        end
    endtask

    task wait_for_clear;
        input integer expected_passes;
        begin
            wait(state_live == 3'd0);
            repeat (2) @(negedge clk);
            check(completed_clears == expected_passes,
                  "clear pass count or termination incorrect");
            check(draw_count == 0 && !stroke_write,
                  "clear completion did not reset drawing/count");
            verify_zero_canvas();
        end
    endtask

    task outside_click;
        input integer x;
        input integer y;
        integer count_before;
        begin
            count_before=draw_count;
            click_at(x,y);
            check(draw_count == count_before && !stroke_active,
                  "outside-canvas pointer unexpectedly drew a cell");
            boundary_tests=boundary_tests+1;
        end
    endtask

    task sample_read;
        input integer x;
        input integer y;
        input integer address;
        input [3:0] data;
        reg [3:0] old_data;
        begin
            @(negedge clk);
            old_data=canvas_rdata;
            pixel_x=x; pixel_y=y;
            #0.001;
            check(canvas_raddr == address,
                  "prefetched pixel coordinate mapped to wrong RAM address");
            check(canvas_rdata === old_data,
                  "synchronous RAM changed data before the clock edge");
            @(posedge clk); #0.001;
            check(canvas_rdata === data,
                  "synchronous RAM read returned wrong color index");
            @(negedge clk);
        end
    endtask

    initial begin
        for (i=0; i<24000; i=i+1) reference_mem[i]=4'hx;
    end

    // Independent RAM model: the read samples the old cell before a
    // same-edge write, matching nonblocking synchronous read-before-write.
    // No testbench code writes the DUT memory or any DUT register.
    always @(posedge clk) begin
        if (!checks_done) begin
            prefetch_x=(pixel_x+1)&2047;
            if (prefetch_x>=112 && prefetch_x<912 && pixel_y>=100 && pixel_y<580)
                sampled_raddr=((pixel_y-100)/4)*200+(prefetch_x-112)/4;
            else
                sampled_raddr=0;
            check(canvas_raddr === sampled_raddr[14:0],
                  "read address or half-open prefetch boundary incorrect");
            expected_read=reference_mem[sampled_raddr];
            sampled_write=ram_we;
            sampled_addr=ram_waddr;
            sampled_data=ram_wdata;

            if (state_live == 3'd3) begin
                if (!previous_clear) clear_steps=0;
                check(ram_we && !stroke_write && ram_wdata == 4'h0,
                      "clear did not own the RAM write port");
                check(clear_addr == clear_steps && ram_waddr == clear_steps,
                      "clear skipped/repeated an address");
                clear_steps=clear_steps+1;
                total_clear_writes=total_clear_writes+1;
            end else if (previous_clear) begin
                check(clear_steps == 24000,
                      "clear did not write exactly 24000 cells");
                check(state_live == 3'd4,
                      "clear did not enter the one-clock CLEAR_DONE state");
                completed_clears=completed_clears+1;
                $display("CH14 clear %0d complete at %0.6f us: writes=%0d",
                         completed_clears,$realtime/1000.0,clear_steps);
            end
            previous_clear=(state_live == 3'd3);
            if (sampled_write) begin
                check(sampled_addr>=0 && sampled_addr<24000,
                      "RAM write address outside the 24000-cell canvas");
                if (sampled_addr>=0 && sampled_addr<24000)
                    reference_mem[sampled_addr]=sampled_data;
                if (state_live != 3'd3) begin
                    check(game_enable && pointer_armed && stroke_active,
                          "ink/erase RAM write occurred before unlocking");
                    if (erase_mode) erase_writes=erase_writes+1;
                    else draw_writes=draw_writes+1;
                end
            end
            #0.001;
            check(canvas_rdata === expected_read,
                  "RAM synchronous read or read-before-write mismatch");
            read_checks=read_checks+1;
            if (sampled_write && sampled_addr>=0 && sampled_addr<24000)
                check(dut.u_game5_paint.canvas_mem[sampled_addr] === sampled_data,
                      "RAM write did not store the requested color index");
            if (rst_n && ui_state_frame == 3'd6) begin
                check(pixel_on && score === draw_count,
                      "fifth-slot score/display selection incorrect");
                check(game_state === {1'b0,(state_live==3'd3),erase_mode,stroke_write},
                      "packed paint status bits incorrect");
            end
        end
    end

    initial begin
        // Entry pointer remains held throughout the full automatic clear.
        at_ns(200); rst_n=1'b1;
        at_ns(1000); case_id=1;
        ui_state_control=3'd6; ui_state_frame=3'd6;
        wait(state_live == 3'd3);
        wait_for_clear(1);
        check(enable == 5'b10000 && selected_color == 2 && !erase_mode,
              "paint-page enable or default red mode incorrect");
        check(!pointer_armed && !stroke_write && draw_count==0,
              "held page-entry pointer left an unwanted mark");
        guard_tests=guard_tests+1;

        // Figure 14-1: release at 500 us, press at 501 us, red RAM cell 1405.
        at_ns(500000); case_id=2; pointer_down=1'b0;
        repeat (2) @(negedge clk);
        check(pointer_armed && !stroke_write,"release did not unlock drawing");
        at_ns(501000); pointer_x=132; pointer_y=128; pointer_down=1'b1;
        repeat (8) @(negedge clk);
        check(pointer_canvas_x==5 && pointer_canvas_y==7 && stroke_addr==1405,
              "screen coordinate (132,128) did not map to logical (5,7)");
        check(cell_1405==2 && draw_count==1 && canvas_rdata==2,
              "first red cell or synchronous read/count incorrect");
        check(pixel_rgb==24'hFF3030,"red palette index did not produce red RGB");
        old_count=draw_count;
        at_ns(502000);
        check(draw_count==old_count,"holding one cell repeatedly incremented draw_count");
        at_ns(502500); pointer_down=1'b0; event_right=1'b1; event_ok=1'b1;
        @(negedge clk); event_right=0; event_ok=0;
        repeat (3) @(negedge clk);
        check(selected_color==2 && state_live==0 && draw_count==1 && cell_1405==2,
              "touch-release events changed palette or cleared the canvas");
        guard_tests=guard_tests+1;

        // Only the two endpoint samples are supplied; every omitted cell
        // must be filled by the original stroke engine.
        at_ns(505000); case_id=3;
        pointer_x=132; pointer_y=128; pointer_down=1'b1;
        repeat (4) @(negedge clk);
        pointer_x=212;
        repeat (30) @(negedge clk);
        for (i=5; i<=25; i=i+1)
            check(dut.u_game5_paint.canvas_mem[1400+i] === 4'h2,
                  "horizontal interpolation left a gap");
        check(draw_count==22,"horizontal interpolation counted wrong cell updates");
        old_count=draw_count;
        repeat (10) @(negedge clk);
        check(draw_count==old_count,"stationary stroke count did not hold");
        release_pointer(); interpolation_tests=interpolation_tests+1;

        at_ns(510000); pointer_x=232; pointer_y=180; pointer_down=1'b1;
        repeat (4) @(negedge clk);
        pointer_x=252; pointer_y=200;
        repeat (12) @(negedge clk);
        release_pointer();
        for (i=0; i<=5; i=i+1)
            check(dut.u_game5_paint.canvas_mem[(20+i)*200+30+i] === 4'h2,
                  "diagonal interpolation left a gap");
        check(draw_count==28,"diagonal interpolation counted wrong cell updates");
        interpolation_tests=interpolation_tests+1;

        // Second color, followed by explicit synchronous read/address tests.
        at_ns(515000); case_id=4; select_palette(4);
        at_ns(519900); pixel_x=192; pixel_y=140;
        at_ns(520000); pointer_x=192; pointer_y=140; pointer_down=1'b1;
        repeat (8) @(negedge clk); release_pointer();
        check(cell_2020==4 && draw_count==29,"blue color/write/count incorrect");
        sample_read(192,140,2020,4'h4);
        check(pixel_rgb==24'h3060FF,"blue palette index did not produce blue RGB");
        sample_read(132,128,1405,4'h2);
        sample_read(191,140,2020,4'h4);
        sample_read(190,140,2019,4'h0);
        sample_read(192,139,1820,4'h0);

        // Prepare nine blue cells, then erase them with the original 3x3
        // nine-clock brush. A nearby blue cell must remain untouched.
        at_ns(525000); case_id=5;
        for (i=9; i<=11; i=i+1)
            for (j=19; j<=21; j=j+1) click_at(112+4*j,100+4*i);
        click_at(112+4*22,100+4*10);
        old_count=draw_count;
        at_ns(532000); click_at(700,30);
        check(erase_mode,"erase toolbar button did not toggle eraser");
        click_at(192,140);
        for (i=9; i<=11; i=i+1)
            for (j=19; j<=21; j=j+1)
                check(dut.u_game5_paint.canvas_mem[i*200+j] === 4'h0,
                      "3x3 eraser left a blue neighbor");
        check(dut.u_game5_paint.canvas_mem[2022] === 4'h4,
              "3x3 eraser changed a cell outside its brush");
        check(draw_count==old_count,"eraser unexpectedly incremented draw_count");
        pulse(7'b0000001); check(!erase_mode,"Up did not restore drawing mode");

        // All ten toolbar colors, keyboard wrap, tool toggles and a swatch gap.
        at_ns(540000); case_id=6;
        for (i=0; i<10; i=i+1) select_palette(i);
        pulse(7'b0001000); check(selected_color==0,"Right failed to wrap 9 to 0");
        pulse(7'b0000100); check(selected_color==9,"Left failed to wrap 0 to 9");
        click_at(77,30); check(selected_color==9,"palette gap changed selected color");
        pulse(7'b0000010); check(erase_mode,"Down did not select eraser");
        pulse(7'b1000000); check(!erase_mode,"Pause did not toggle eraser off");
        select_palette(2);

        // Half-open canvas bounds and all four pointer-coordinate corners.
        at_ns(555000); case_id=7;
        click_at(112,100); click_at(911,100);
        click_at(112,579); click_at(911,579);
        check(cell_0==2 && cell_23999==2 &&
              dut.u_game5_paint.canvas_mem[199]==2 &&
              dut.u_game5_paint.canvas_mem[23800]==2,
              "one of the four canvas corners mapped incorrectly");
        boundary_tests=boundary_tests+4;
        sample_read(112,100,0,4'h2);
        sample_read(910,100,199,4'h2);
        sample_read(112,579,23800,4'h2);
        sample_read(910,579,23999,4'h2);
        sample_read(911,579,0,4'h2); // actual prefetch outside -> safe address 0
        sample_read(111,100,0,4'h2); // prefetch reaches the first logical cell
        sample_read(912,579,0,4'h2);
        sample_read(911,580,0,4'h2);
        at_ns(560000);
        outside_click(111,100); outside_click(912,579);
        outside_click(911,580); outside_click(112,99);

        // At each corner the 3x3 eraser clips to legal cells. Some phases
        // deliberately repeat an edge address; all writes stay within RAM.
        at_ns(565000); case_id=8; pulse(7'b1000000);
        click_at(112,100); click_at(911,100);
        click_at(112,579); click_at(911,579);
        check(cell_0==0 && cell_23999==0 &&
              dut.u_game5_paint.canvas_mem[199]==0 &&
              dut.u_game5_paint.canvas_mem[23800]==0,
              "clipped corner eraser failed");
        boundary_tests=boundary_tests+4;
        select_palette(2);
        sample_read(192,140,2020,4'h0);

        // Figure 14-2: toolbar clear, with held canvas input and keyboard
        // requests during the traversal. They cannot replace clear writes.
        at_ns(700000); case_id=9;
        pointer_x=860; pointer_y=30; pointer_down=1'b1;
        repeat (3) @(negedge clk);
        check(state_live==3 && draw_count==0,"clear toolbar did not start clearing");
        pointer_x=192; pointer_y=140;
        pulse(7'b1001000);
        check(selected_color==2 && !erase_mode && !stroke_write,
              "input during clearing changed drawing state");
        wait(clear_addr==23995);
        @(negedge clk); pointer_down=1'b0;
        wait_for_clear(2);
        check(pointer_armed,"clear completion lost the released-pointer unlock");

        at_ns(1170000); case_id=10;
        pointer_x=192; pointer_y=140; pointer_down=1'b1;
        repeat (8) @(negedge clk);
        check(cell_2020==2 && draw_count==1,"first post-clear stroke did not recover");
        release_pointer();

        // Exit is an output request; the testbench acts as the page controller.
        at_ns(1200000); case_id=11;
        @(negedge clk); event_back=1'b1; #0.001;
        check(exit_request && dut.slot_exit[4],"paint Back did not request exit");
        @(negedge clk); event_back=1'b0;
        ui_state_control=3'd1; ui_state_frame=3'd1;
        repeat (3) @(negedge clk);
        check(!game_enable && !exit_request && !pointer_armed && draw_count==0,
              "inactive page did not reset control state");
        check(cell_2020==2,"leaving the page unexpectedly initialized RAM");
        old_count=draw_writes;
        pointer_down=1'b1;
        repeat (12) @(negedge clk);
        check(draw_writes==old_count,"inactive page accepted a held pointer");

        // Reentry again clears RAM through the normal port and requires release.
        at_ns(1250000); case_id=12;
        ui_state_control=3'd6; ui_state_frame=3'd6;
        wait(state_live==3); wait_for_clear(3);
        check(!pointer_armed && draw_count==0,"reentry bypassed pointer release guard");
        at_ns(1730000); release_pointer();
        at_ns(1740000); click_at(132,128);
        check(cell_1405==2 && draw_count==1,"drawing after reentry did not recover");
        guard_tests=guard_tests+1;

        // Keyboard OK provides the alternative clear trigger when no pointer
        // gesture is active. Original size and clock are still retained.
        at_ns(1800000); case_id=13; pulse(7'b0010000);
        check(state_live==3,"released-pointer OK did not trigger clear");
        wait_for_clear(4);
        at_ns(2300000); select_palette(4); click_at(192,140);
        sample_read(192,140,2020,4'h4);
        check(cell_2020==4 && draw_count==1,"drawing after keyboard clear failed");

        // Async reset is checked while the page is inactive; the next page
        // entry, rather than a hidden RAM initialization, would clear memory.
        at_ns(2400000); case_id=14;
        ui_state_control=3'd1; ui_state_frame=3'd1;
        repeat (2) @(negedge clk);
        #2; rst_n=1'b0; #0.001;
        check(state_live==0 && selected_color==2 && !erase_mode &&
              !pointer_armed && !stroke_active && draw_count==0,
              "asynchronous reset left stale control state");
        repeat (3) @(negedge clk); rst_n=1'b1;

        at_ns(2450000); case_id=15;
        check(completed_clears==4 && total_clear_writes==96000,
              "full-size clear coverage incomplete");
        check(palette_tests>=12 && boundary_tests==12 &&
              interpolation_tests==2 && guard_tests==3 && erase_writes>=45,
              "chapter test coverage incomplete");
        checks_pass=(errors==0); checks_done=1'b1;
        if (checks_pass)
            $display("CH14 PASS: clears=%0d clear_writes=%0d palette=%0d bounds=%0d interpolation=%0d guards=%0d erase_writes=%0d reads=%0d errors=%0d",
                     completed_clears,total_clear_writes,palette_tests,boundary_tests,
                     interpolation_tests,guard_tests,erase_writes,read_checks,errors);
        else
            $display("CH14 FAIL: errors=%0d",errors);
    end
endmodule
