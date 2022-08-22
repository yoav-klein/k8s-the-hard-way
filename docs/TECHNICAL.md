# Technical Specification

This document deep dives to the technical details of the project.

## Structure

The project is structured in such a way that for each step in the bootstrapping process there is
a directory which holds all the files and scripts necessary to perform the step in question.

These include:
1. Creating the certificates for the cluster
2. Creating the kubeconfigs
3. Bootstrapping the etcd cluster
4. Bootstrapping the control plane
5. Bootstrapping the worker nodes
6. Configuring networking and DNS

The first 2 steps are done using a Makefile. See inside.

The next 3 steps are the more complicated part, and they follow a similar pattern.
For each of them, bootstrapping contains the following steps:
1. build (creating a deployment directory) - basically just replacing tokens in template files
2. distribute those files to the nodes, to a "landing" directory (in the user's home directory)
3. using the `agent` script on each node to bootstrap the component in question

The agent script accepts commands, each does a small portion of the bootstraping process.
These include installing the required binaries, installing the services, running the services,
and the undos of those functions.

The manager script has a corresponding command for each command in the agent script, which will 
iterate over the nodes and activate the same  command using the agent script on the node. 
For example, running `cp_manager.sh install_binaries` will iterate over all controller nodes, running `cp_agent.sh install_binaries`.

So basically, you can use the agent script on each node independently (something you'll usually only do if you're facing any problems).

In addition, the manager scripts contain the commands: `bootstrap` and `reset`, which will 
run all the steps required to bootstrap the component from scratch - i.e. - create a deployment, 
distribute to nodes, install binaries, etc., and `test` - which will test if the component is bootstrapped successfully.


## Idempotency
We try to be idempotent as possible. This is done in the following manner:

In each command, the agent will check if it's already in this state. If is,
it will return a specific status code (2) that indicates that this action 
is not necessary on this node. The manager script will then go on to the next node.

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
