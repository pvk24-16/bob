import subprocess
import platform

import os
import sys

if platform.system() == 'Windows':
    subprocess.call(['..\\..\\..\\examples\\fountain\\visualizern\\win\\Fountain.exe'])
elif platform.system() == 'Linux':
    subprocess.call(['./examples/fountain/linux/Fountain.x86_64'])
elif platform.system() == 'Darwin':
    pass