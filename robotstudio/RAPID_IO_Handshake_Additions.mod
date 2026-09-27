MODULE CellHandshake
    ! =====================================================================
    ! RAPID additions to add to your existing MIG_Weld.mod / TIG_Weld.mod
    ! project so the robot waits for a PLC cycle-start command and reports
    ! ready/busy/complete status back — the software equivalent of the
    ! Modbus coils/registers exposed by robot_modbus_proxy.py.
    !
    ! In a real cell these would be mapped to physical I/O signals
    ! configured in the IRC5/OmniCore I/O configuration (EtherNet/IP or
    ! DeviceNet board). Here they're declared as simulated signals so you
    ! can test the handshake purely in RobotStudio's virtual controller.
    ! =====================================================================

    ! ---- Simulated I/O signals (configure these in RobotStudio's
    !      Controller > Configuration > I/O System, or via Virtual I/O) ----
    VAR signaldi di_CycleStart;     ! Input from PLC: start weld cycle
    VAR signaldo do_RobotReady;     ! Output to PLC: robot idle/available
    VAR signaldo do_RobotBusy;      ! Output to PLC: robot executing cycle
    VAR signaldo do_RobotFault;     ! Output to PLC: robot fault state
    VAR signaldo do_WeldComplete;   ! Output to PLC: pulse on cycle complete

    VAR num cycleCount := 0;

    PROC main()
        SetDO do_RobotReady, 1;
        SetDO do_RobotBusy, 0;
        SetDO do_RobotFault, 0;
        SetDO do_WeldComplete, 0;

        WHILE TRUE DO
            WaitDI di_CycleStart, 1;      ! block until PLC commands start

            SetDO do_RobotReady, 0;
            SetDO do_RobotBusy, 1;

            ! ---- existing weld routine call goes here ----
            ! Example: replace with your actual MIG/TIG routine names
            ProcCall RunWeldCycle;

            cycleCount := cycleCount + 1;
            SetDO do_RobotBusy, 0;
            SetDO do_WeldComplete, 1;
            WaitTime 0.2;
            SetDO do_WeldComplete, 0;
            SetDO do_RobotReady, 1;

            WaitDI di_CycleStart, 0;      ! wait for PLC to drop start bit before next cycle
        ENDWHILE
    ENDPROC

    ! ---------------------------------------------------------------------
    ! Wrapper that calls your existing weld logic. Point this at your
    ! MIG_Weld / TIG_Weld PROCs (e.g., mig_weld_main, tig_weld_main).
    ! ---------------------------------------------------------------------
    PROC RunWeldCycle()
        ! TODO: replace with call to your existing routine, e.g.:
        ! mig_weld_main;
        MoveJ pHome, v1000, fine, tool0;
        ! ArcLStart/ArcL/ArcLEnd sequence from your existing module
        MoveJ pHome, v1000, fine, tool0;
    ENDPROC

    ! ---------------------------------------------------------------------
    ! Fault handling: call this from an error handler / TRAP routine tied
    ! to your existing weld modules to set do_RobotFault for the PLC.
    ! ---------------------------------------------------------------------
    PROC SetRobotFault()
        SetDO do_RobotFault, 1;
        SetDO do_RobotBusy, 0;
        SetDO do_RobotReady, 0;
    ENDPROC

ENDMODULE
