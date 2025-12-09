from ghidra.app.decompiler import DecompInterface
from ghidra.util.task import ConsoleTaskMonitor


def run():
    program = currentProgram
    decomp = DecompInterface()
    decomp.openProgram(program)
    monitor = ConsoleTaskMonitor()

    func_manager = program.getFunctionManager()
    functions = func_manager.getFunctions(True)

    output_data = []

    for func in functions:
        if func.isThunk() or func.isExternal():
            continue

        results = decomp.decompileFunction(func, 0, monitor)

        if results.decompileCompleted():
            c_code = results.getDecompiledFunction().getC()
            func_name = func.getName()

            print("<<<<START_FUNC:{}>>>>".format(func_name))
            print(c_code)
            print("<<<<END_FUNC>>>>")


run()
