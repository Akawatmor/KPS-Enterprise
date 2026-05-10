import pexpect
import sys

def run_cmd():
    password = "Petchsony42024"
    command = 'ssh -o StrictHostKeyChecking=no skoadmin@192.168.1.142 "sudo kubectl delete statefulset todoapp-postgres -n todoapp --cascade=orphan"'
    
    child = pexpect.spawn(command, encoding='utf-8')
    child.logfile = sys.stdout
    
    # Handle SSH password prompt
    idx = child.expect(['password:', pexpect.EOF, pexpect.TIMEOUT])
    if idx == 0:
        child.sendline(password)
    
    # Handle sudo password prompt (if it appears after SSH)
    idx = child.expect(['password for skoadmin:', '\[sudo\] password for skoadmin:', pexpect.EOF, pexpect.TIMEOUT])
    if idx == 0 or idx == 1:
        child.sendline(password)
    
    child.expect(pexpect.EOF)

if __name__ == "__main__":
    run_cmd()
