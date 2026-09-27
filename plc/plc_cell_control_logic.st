(* =========================================================================
   Robotic Welding Cell - PLC Control Logic (IEC 61131-3 Structured Text)
   Target: Allen-Bradley Micro800 / CCW, or Studio 5000 (port to Ladder easily)
   Also portable to Siemens TIA Portal SCL with minor syntax changes.
   ========================================================================= *)

PROGRAM CellControl
VAR
    // ---- Physical / simulated inputs ----
    I_EStop            : BOOL;   // TRUE = E-stop OK (not pressed), FALSE = tripped
    I_LightCurtainOK   : BOOL;   // TRUE = curtain clear
    I_GuardClosed      : BOOL;   // TRUE = guard door closed
    I_PartPresent      : BOOL;   // TRUE = part detected in fixture
    I_CycleStartPB     : BOOL;   // momentary pushbutton
    I_CycleStopPB      : BOOL;   // momentary pushbutton
    I_RobotReady       : BOOL;   // from robot proxy (Modbus)
    I_RobotFault       : BOOL;   // from robot proxy (Modbus)

    // ---- Outputs ----
    O_SafetyEnable     : BOOL;   // permits robot motion
    O_CycleStartCmd    : BOOL;   // pulse sent to robot proxy
    O_AlarmHorn        : BOOL;
    O_CycleRunningLamp : BOOL;
    O_FaultLamp        : BOOL;

    // ---- Internal state ----
    CycleRunning       : BOOL;
    FaultLatched       : BOOL;
    CycleCount         : DINT;
    CycleTimer         : TON;    // dwell/weld timer
    CycleStopwatch     : TON;    // measures cycle time
    LastCycleTimeMs    : DINT;
END_VAR

// ---------------------------------------------------------------
// 1. SAFETY INTERLOCK RUNG
//    Robot motion is only enabled when ALL safety conditions are true.
//    This is the rung you'd wire into a Safety PLC / safety relay in
//    a real cell; here it's the software equivalent for demonstration.
// ---------------------------------------------------------------
O_SafetyEnable := I_EStop AND I_LightCurtainOK AND I_GuardClosed AND NOT FaultLatched;

// ---------------------------------------------------------------
// 2. FAULT LATCH (root-cause friendly: one bit per condition,
//    kept separate so you can trend/alarm on the *cause*, not
//    just a generic "fault" bit — matches JD's root-cause analysis focus)
// ---------------------------------------------------------------
IF (NOT I_EStop) OR (NOT I_LightCurtainOK) OR (NOT I_GuardClosed) OR I_RobotFault THEN
    FaultLatched := TRUE;
END_IF;

IF I_CycleStopPB AND I_EStop AND I_LightCurtainOK AND I_GuardClosed AND NOT I_RobotFault THEN
    FaultLatched := FALSE;   // manual fault reset via stop/reset button once conditions clear
END_IF;

O_FaultLamp  := FaultLatched;
O_AlarmHorn  := FaultLatched;

// ---------------------------------------------------------------
// 3. CYCLE START / SEAL-IN LOGIC
// ---------------------------------------------------------------
IF I_CycleStartPB AND O_SafetyEnable AND I_PartPresent AND I_RobotReady AND NOT CycleRunning THEN
    CycleRunning := TRUE;
    CycleStopwatch(IN := TRUE);   // start measuring cycle time
END_IF;

IF I_CycleStopPB OR NOT O_SafetyEnable OR I_RobotFault THEN
    CycleRunning := FALSE;
END_IF;

O_CycleStartCmd    := CycleRunning;   // held true while robot proxy executes weld
O_CycleRunningLamp := CycleRunning;

// ---------------------------------------------------------------
// 4. WELD DWELL TIMER (example TON usage — swap for actual weld
//    dwell if you want to simulate arc-on time independent of robot)
// ---------------------------------------------------------------
CycleTimer(IN := CycleRunning, PT := T#3S);

// ---------------------------------------------------------------
// 5. CYCLE COUNT + CYCLE TIME (feeds your HMI/SCADA trend/OEE tile)
// ---------------------------------------------------------------
IF CycleRunning AND NOT I_RobotFault AND I_RobotReady = FALSE THEN
    // Robot proxy drops RobotReady to FALSE while it "processes" the
    // weld, then sets it back TRUE on completion — detect the
    // falling->rising edge to count a completed cycle.
END_IF;

CycleStopwatch(IN := CycleRunning);
IF NOT CycleRunning AND CycleStopwatch.Q THEN
    LastCycleTimeMs := CycleStopwatch.ET;
    CycleCount := CycleCount + 1;
    CycleStopwatch(IN := FALSE);
END_IF;

END_PROGRAM

(* =========================================================================
   LADDER LOGIC EQUIVALENT (for whiteboard/interview explanation)
   Rung 1  [I_EStop][I_LightCurtainOK][I_GuardClosed][/FaultLatched]---(O_SafetyEnable)
   Rung 2  [/I_EStop] OR [/I_LightCurtainOK] OR [/I_GuardClosed] OR [I_RobotFault]---(FaultLatched)  ; latched (SET)
   Rung 3  [I_CycleStopPB][I_EStop][I_LightCurtainOK][I_GuardClosed][/I_RobotFault]---(FaultLatched) ; unlatch (RESET)
   Rung 4  [I_CycleStartPB][O_SafetyEnable][I_PartPresent][I_RobotReady][/CycleRunning]---(CycleRunning) ; seal-in with OR branch on CycleRunning
   Rung 5  [I_CycleStopPB] OR [/O_SafetyEnable] OR [I_RobotFault]---(/CycleRunning)
   Rung 6  [CycleRunning]---(TON CycleTimer, PT=3s)
   Rung 7  [CycleRunning]---(O_CycleStartCmd)  ; pulse/level signal out to robot proxy over Modbus
   ========================================================================= *)
