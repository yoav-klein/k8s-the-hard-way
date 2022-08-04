




## Technical Notes


### Structure

After creating the certificates and kubeconfigs, we have 3 major stages in setting up our cluster:
1. etcd
2. control plane
3. worker nodes

Each has its own directory with its necessary files.
In each of them we follow the same pattern. bootstraping a component contains the following steps:
1. creating a deployment directory - basically just replacing tokens in template files
2. distribute those files to the nodes
3. using the `agent` script on each node to bootstrap the component in question

The agent script accepts commands, each does a small portion of the bootstraping process.
These include installing the required binaries, installing the services, running the services,
and the undos of those functions.

The manager script has a corresponding command for each command in the agent script.
For each of these commands, the manager will iterate over the nodes and activate the same
command using the agent script on the node. For example, running `cp_manager.sh install_binaries`
will iterate over all controller nodes, running `cp_agent.sh install_binaries`.

In addition, the manager scripts have 2 more commands: `bootstrap` and `reset`, which will 
run all the steps required to bootstrap the component from scratch - i.e. - create a deployment, 
distribute to nodes, install binaries, etc.

#### Idempotency
We try to be idempotent as possible. This is done in the following manner:
In each command, the agent will check if it's already in this state. If is,
it will return a specific status code (2) that indicates that this action 
is not necessary on this node. The manager script will then go on to the next node.

The negative commands (i.e. delete_binaries, delete_services) are safe - 
if a file is not present, the agent won't try to delete it. If a service is down,
the agent won't try to stop it.

#### What happens on error?
We divide the commands into "positive" and "negative".
For the positive commands, once we encounter an error, we'll try stop execution,
trying to undo any side-effects done until that point, leaving a clean state.
For the negative commands, we'll inform the user about the error, and if there's
anything else to do in this command, we'll attempt to do it anyways.

On the manager side, once an error occurs, or a node is not ready for the command,
we stop execution.
