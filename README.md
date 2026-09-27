# Robotic Welding Cell Integration

A simulated production cell that integrates an **ABB robot** (RobotStudio/RAPID), a **PLC** (IEC 61131-3 Structured Text / Ladder Logic), and an **HMI/SCADA** layer over **Modbus TCP** networking — built to demonstrate Controls Engineer / Automation & Robotics skills required for industrial manufacturing roles: ABB robot programming, PLC logic, HMI/SCADA development, industrial networking, and safety interlocks.

## Architecture

```
HMI (Ignition)  <-- Modbus/OPC -->  PLC (Studio 5000 / CCW)  <-- Modbus TCP -->  Robot Proxy (Python)  <-- RAPID I/O -->  ABB RobotStudio (virtual controller)
```

The PLC owns safety interlocks and cycle sequencing. It commands the robot over Modbus TCP (simulating an EtherNet/IP-style handshake to an IRC5/OmniCore controller). The robot proxy stands in for the real ABB controller until this is deployed against physical/virtual RobotStudio I/O. The HMI gives an operator view of status, alarms, and cycle metrics.

## Project Structure

```
├── plc/
│   └── plc_cell_control_logic.st       # Safety interlock, fault latch, cycle-start logic (ST + ladder-rung comments)
├── robot_proxy/
│   └── robot_modbus_proxy.py           # Python Modbus TCP server simulating the ABB robot controller
├── robotstudio/
│   └── RAPID_IO_Handshake_Additions.mod # RAPID module: PLC handshake signals around existing MIG/TIG weld routine
└── README.md
```

## Component Details

### PLC Logic (`plc/plc_cell_control_logic.st`)
Implements, in IEC 61131-3 Structured Text (portable to Ladder or Siemens SCL):
- Safety interlock rung: robot motion enabled only when E-stop, light curtain, and guard are all clear.
- Latched fault handling: one bit per failure cause (E-stop, light curtain, guard, robot fault) for root-cause-friendly diagnostics, with a manual reset condition.
- Cycle-start seal-in logic gated on safety, part-present, and robot-ready signals.
- A `TON` weld-dwell timer and a cycle-time stopwatch feeding cycle count/time for HMI display.

Ladder-rung equivalents are documented inline as comments for direct transcription into Studio 5000 or CCW's ladder editor.

### Robot Proxy (`robot_proxy/robot_modbus_proxy.py`)
A Modbus TCP server that simulates an ABB IRC5/OmniCore controller's I/O gateway:

| Register type | Address | Signal |
|---|---|---|
| Coil (R/W) | 0 | `Cycle_Start_Cmd` — PLC commands a weld cycle |
| Discrete Input | 0 | `Robot_Ready` |
| Discrete Input | 1 | `Robot_Fault` |
| Discrete Input | 2 | `Robot_Busy` |
| Holding Register | 0 | `Last_Cycle_Time_ms` |
| Holding Register | 1 | `Cycle_Count` |

**Run it:**
```bash
pip install pymodbus
python robot_proxy/robot_modbus_proxy.py
```
It listens on `127.0.0.1:5020`. Point any PLC's Modbus TCP master (or a tool like ModbusPoll) at that address to test the handshake before wiring in a real PLC program.

### RAPID Module (`robotstudio/RAPID_IO_Handshake_Additions.mod`)
Adds the robot-side half of the handshake inside RobotStudio: `di_CycleStart` blocks program execution until the PLC signals start, then the robot sets busy/ready/fault outputs and calls into the existing weld routine via the `RunWeldCycle` wrapper — replace the placeholder motion commands with a call to your actual `MIG_Weld.mod`/`TIG_Weld.mod` procedures.

## How to Test End-to-End

1. Start the robot proxy: `python robot_proxy/robot_modbus_proxy.py`.
2. Build the PLC program (CCW, PLCLogix, or Studio 5000) using the logic in `plc_cell_control_logic.st`, and configure its Modbus TCP master to poll `127.0.0.1:5020`.
3. Toggle the PLC's start conditions (E-stop clear, part present, cycle-start pressed) and confirm the terminal log shows the robot proxy executing and completing a simulated weld cycle.
4. Open the RobotStudio station, load `RAPID_IO_Handshake_Additions.mod` alongside the existing weld modules, add the referenced I/O signals in the virtual controller's I/O configuration, and confirm the robot waits for and responds to `di_CycleStart`.
5. Optionally, add an Ignition (or similar) HMI screen bound to the PLC's tags to visualize start/stop, alarms, and cycle count.

## Skills Demonstrated

- ABB robot programming (RAPID, RobotStudio, I/O configuration, robotic welding)
- PLC programming (Ladder Logic and Structured Text, timers/counters, safety interlocks)
- HMI/SCADA development (operator screens, alarms, diagnostics)
- Industrial networking (Modbus TCP; concepts transferable to EtherNet/IP and PROFINET)
- Root-cause-oriented fault latching and equipment diagnostics
- Robotic welding process integration and cycle-time optimization

## License

This project is for portfolio and learning purposes.
