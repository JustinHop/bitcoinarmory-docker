from __future__ import print_function
################################################################################
#                                                                              #
# Copyright (C) 2011-2015, Armory Technologies, Inc.                           #
# Distributed under the GNU Affero General Public License (AGPL v3)            #
# See LICENSE or http://www.gnu.org/licenses/agpl.html                         #
#                                                                              #
################################################################################
import sys
import time
import platform
import os
import signal
import subprocess
import psutil

# Note:  this ended up not being used for Windows!  Check out guardian.exe
OPSYS = platform.system()
OS_WINDOWS = 'win32' in OPSYS.lower() or 'windows' in OPSYS.lower()

try:
    PID_ARMORY = int(sys.argv[1])
    PID_BITCOIND = int(sys.argv[2])
except:
    print('USAGE: %d armorypid bitcoindpid' % sys.argv[0])
    exit(0)


def check_pid(pid, name=''):
    try:
        proc = psutil.Process(pid)
        procstr = ' '.join(proc.cmdline)
        if name == '':
            return procstr
        else:
            return procstr if procstr == name else False
    except psutil.NoSuchProcess:
        return False


def kill(pid):
    if OS_WINDOWS:
        #import ctypes
        #k32 = ctypes.windll.kernel32
        #handle = k32.OpenProcess(1,0,pid)
        # return (0 != k32.TerminateProcess(handle,0))
        os.kill(pid, signal.CTRL_C_EVENT)
    else:
        os.kill(pid, signal.SIGTERM)
        time.sleep(3)
        if not check_pid(pid):
            return

        print('Regular TERMINATE of bitcoind failed; issuing SIGKILL (hard)')
        time.sleep(1)
        os.kill(pid, signal.SIGKILL)


################################################################################
def killProcessTree(pid):
    # In this case, Windows is easier because we know it has the get_children
    # call, because have bundled a recent version of psutil.  Linux, however,
    # does not have that function call in earlier versions.
    if OS_WINDOWS:
        for child in psutil.Process(pid).get_children():
            kill(child.pid)
    else:
        proc = subprocess.Popen("ps -o pid --ppid %d --noheaders" %
                                pid, shell=True, stdout=subprocess.PIPE)
        out, err = proc.communicate()
        for pid_str in out.split("\n")[:-1]:
            kill(int(pid_str))


# Verify the two PIDs are valid
PROC_NAME_ARMORY = check_pid(PID_ARMORY)
PROC_NAME_BITCOIND = check_pid(PID_BITCOIND)

if PROC_NAME_ARMORY:
    print('ArmoryQt is running in pid=%d (%s)' %
          (PID_ARMORY, PROC_NAME_ARMORY))
else:
    print('ArmoryQt IS NOT RUNNING!')


if PROC_NAME_BITCOIND:
    print('bitcoind is running in pid=%d (%s)' %
          (PID_BITCOIND, PROC_NAME_BITCOIND))
else:
    print('bitcoind IS NOT RUNNING!')


while True:
    time.sleep(3)

    if not check_pid(PID_ARMORY, PROC_NAME_ARMORY):
        #print 'ArmoryQt died!'
        break

    if not check_pid(PID_BITCOIND, PROC_NAME_BITCOIND):
        #print 'bitcoind disappeared -- guardian exiting'
        exit(0)


if check_pid(PID_BITCOIND, PROC_NAME_BITCOIND):

    # Depending on how popen was called, bitcoind may be a child of
    # PID_BITCOIND.  But psutil makes it easy to find those child procs
    # and kill them.
    killProcessTree(PID_BITCOIND)
    kill(PID_BITCOIND)
