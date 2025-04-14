import subprocess
import platform

if platform.system() == 'Windows':
    subprocess.call(['.\\examples\\fountain\\Fountain.exe'])
elif platform.system() == 'Linux':
    pass
elif platform.system() == 'Darwin':
    pass