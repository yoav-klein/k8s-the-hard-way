# Technical Specification

This document deep dives to the technical details of the project.

## Structure

After creating the certificates and kubeconfigs, we have 3 major stages in setting up our cluster:
1. etcd
2. control plane
3. worker nodes

Each has its own directory with its necessary files.
In each of them we follow the same pattern. bootstraping a component contains the following steps:
1. build (creating a deployment directory) - basically just replacing tokens in template files
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

## Idempotency
We try to be idempotent as possible. This is done in the following manner:

In each command, the agent will check if it's already in this state. If is,
it will return a specific status code (2) that indicates that this action 
is not necessary on this node. The manager script will then go on to the next node.

The negative commands (i.e. delete_binaries, delete_services) are safe - 
if a file is not present, the agent won't try to delete it. If a service is down,
the agent won't try to stop it.

## Error Handling
We divide the commands into "positive" and "negative".

On the agent side:
For the positive commands, once we encounter an error, we stop execution,
trying to undo any side-effects done until that point, leaving a well-defined state.
For the negative commands, we'll inform the user about the error, and if there's
anything else to do in this command, we'll attempt to do it anyways.

On the manager side:
We mentioned that for each command on the agent, we have a corresponding command on the manager
that iterates over all the nodes and executes this command.
So for the positive commands, whenever a node fails, we don't go on to the next nodes.
For the negative commands, we go on to the next nodes, doing a best effort to do the negative command.

For example, if we run `start`, and the second node fails, we won't go on to the third node.
But if we run `stop`, and the second node fails, we will try to stop the third node.
