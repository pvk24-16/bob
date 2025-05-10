import subprocess
import platform

if platform.system() == 'Windows':
    subprocess.call(['..\\..\\..\\examples\\fountain\\visualizern\\win\\Fountain.exe'])
elif platform.system() == 'Linux':
    subprocess.call(['./examples/fountain/linux/Fountain.x86_64'])
elif platform.system() == 'Darwin':
    print('\033[91m Fountain is not supported on macOS! \033[00m')