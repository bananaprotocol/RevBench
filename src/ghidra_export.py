from ghidra.app.decompiler import DecompInterface
from ghidra.util.task import ConsoleTaskMonitor


def run():
    program = currentProgram
    decomp = DecompInterface()
    decomp.openProgram(program)
    monitor = ConsoleTaskMonitor()

    filename = program.getName()

    func_manager = program.getFunctionManager()
    functions = func_manager.getFunctions(True)

    code_output = ""

    for func in functions:
        if func.isThunk() or func.isExternal():
            continue

        results = decomp.decompileFunction(func, 0, monitor)

        if results.decompileCompleted():
            c_code = results.getDecompiledFunction().getC()
            code_output += c_code + "\n"

    if code_output:
        print("<<<<START_FILE:{0}>>>>".format(filename))
        print(code_output)
        print("<<<<END_FILE>>>>")


run()
