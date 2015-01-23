# Get the status of a STv3 deployment.
# Returns:
#  - tail of each worker log on each worker node
#  - status of each rabbit server queue
#
# Requires a config file that has:
#  - location of your worker nodes
#  - name of your rabbit vhost
#  - name of your rabbit queues
#
# You will need a credentials for a user that
# can access all of these servers.

"""stv3_status - StackTach.v3 diagnostics utility.
Usage:
  stv3_status.py <config_file>
  stv3_status.py <config_file> -u <username>
  stv3_status.py <config_file> -u <username> -p <password>
  stv3_status.py (-h | --help)
  stv3_status.py --version
  stv3_status.py --debug
Options:
  -h --help     Show this help message
  --version     Show klugman version
  --debug       Debug mode
"""

from docopt import docopt
import pxssh
import tempfile
import yaml

import pxssh


def ssh(host, cmds, user, password, port):
    s = pxssh.pxssh()
    if not s.login (host, user, password, port=port):
        print "SSH session failed on login."
        print str(s)
        return None
    outputs = []
    for cmd in cmds:
        s.sendline(cmd)
        s.prompt()
        outputs.append(s.before)
    s.logout()
    return outputs


arguments = docopt(__doc__, options_first=True)

config = {}
config_file = arguments.get('<config_file>')
if config_file:
    with open(config_file, 'r') as f:
        config = yaml.load(f)

debug = arguments.get('--debug', False)

if debug:
    print config

cell_names = config['cell_names']
username = config.get('username')
password = config.get('password')
worker_hostnames = config['worker_hostnames']
rabbit_hostnames = config['rabbit_hostnames']
port = int(config.get('ssh_port', 22))
vhost = config.get('vhost', '/')
lines = config.get('tail_lines', '100')
queue_prefixes = config.get('queue_prefixes', ['monitor'])

for worker in worker_hostnames:
    for cell in cell_names:
        print "--- Worker: %s Cell: %s" % (worker, cell)
        ret = ssh(worker,
                      ["tail --lines %s /var/log/stv3/yagi-%s.log" %
                            (lines, cell),
                       "ps aux | grep -E 'yagi-event|pipeline_worker'"],
                  username, password, port)
        with open("yagi-%s.log" % cell, "w") as o:
            o.write(ret[0])
        print ret[1]

prefixes = '|'.join(queue_prefixes)
for rabbit in rabbit_hostnames:
    print "--- RabbitMQ: %s vhost: %s" % (rabbit, vhost)
    ret = ssh(rabbit, ["sudo rabbitmqctl list_queues -p %s | grep -E '%s'" %
                            (vhost, prefixes)],
                       username, password, port)
    for r in ret:
        print r