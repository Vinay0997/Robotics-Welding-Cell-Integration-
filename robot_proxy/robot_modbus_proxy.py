"""
robot_modbus_proxy.py
----------------------
Simulates an ABB robot controller exposed over Modbus TCP so a PLC
(Studio 5000 / CCW / any Modbus master) can command and monitor it
the way it would a real IRC5/OmniCore controller via an I/O gateway.

Coils (read/write, PLC -> robot):
    0  Cycle_Start_Cmd   (PLC sets TRUE to command a weld cycle)

Discrete Inputs (read-only, robot -> PLC):
    0  Robot_Ready
    1  Robot_Fault
    2  Robot_Busy

Holding Registers (read-only, robot -> PLC):
    0  Last_Cycle_Time_ms (low word)
    1  Cycle_Count

Run:
    pip install pymodbus
    python robot_modbus_proxy.py
Then point your PLC simulator's Modbus TCP master at 127.0.0.1:5020.
"""

import logging
import threading
import time

from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusSlaveContext,
    ModbusServerContext,
)
from pymodbus.server import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("robot_proxy")

WELD_CYCLE_SECONDS = 3.0   # simulated arc-on / weld dwell time
HOST, PORT = "127.0.0.1", 5020


class RobotState:
    def __init__(self):
        self.ready = True
        self.fault = False
        self.busy = False
        self.cycle_count = 0
        self.last_cycle_ms = 0

    def run_cycle(self):
        """Simulates executing MIG_Weld.mod / TIG_Weld.mod in RobotStudio."""
        self.ready = False
        self.busy = True
        start = time.time()
        log.info("Robot: cycle start -> executing weld routine")
        time.sleep(WELD_CYCLE_SECONDS)
        self.last_cycle_ms = int((time.time() - start) * 1000)
        self.cycle_count += 1
        self.busy = False
        self.ready = True
        log.info(
            "Robot: cycle complete #%d, %d ms",
            self.cycle_count, self.last_cycle_ms,
        )


def build_context(robot: RobotState):
    coils = ModbusSequentialDataBlock(0, [0] * 8)
    discrete = ModbusSequentialDataBlock(0, [0] * 8)
    holding = ModbusSequentialDataBlock(0, [0] * 8)
    store = ModbusSlaveContext(
        di=discrete, co=coils, hr=holding, ir=holding, zero_mode=True
    )
    return ModbusServerContext(slaves=store, single=True), coils, discrete, holding


def poll_loop(context, robot: RobotState):
    """Watches the Cycle_Start_Cmd coil; when the PLC sets it TRUE,
    kicks off the simulated weld cycle in a background thread and
    updates the discrete-input / holding-register status."""
    slave_id = 0x00
    last_cmd = False
    while True:
        cmd_values = context[slave_id].getValues(1, 0, count=1)  # coil 0
        cmd = bool(cmd_values[0])

        if cmd and not last_cmd and robot.ready and not robot.busy:
            threading.Thread(target=robot.run_cycle, daemon=True).start()
        last_cmd = cmd

        context[slave_id].setValues(2, 0, [int(robot.ready), int(robot.fault), int(robot.busy)])  # discrete inputs
        context[slave_id].setValues(3, 0, [robot.last_cycle_ms & 0xFFFF, robot.cycle_count])       # holding regs

        time.sleep(0.1)


def main():
    robot = RobotState()
    context, coils, discrete, holding = build_context(robot)

    identity = ModbusDeviceIdentification()
    identity.VendorName = "SimulatedRobotProxy"
    identity.ProductName = "ABB IRC5/OmniCore Modbus Gateway (simulated)"

    t = threading.Thread(target=poll_loop, args=(context, robot), daemon=True)
    t.start()

    log.info("Robot Modbus proxy listening on %s:%d", HOST, PORT)
    StartTcpServer(context=context, identity=identity, address=(HOST, PORT))


if __name__ == "__main__":
    main()
