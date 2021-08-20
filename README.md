# gcommands

Some commands to make working with gcloud easier.

## usage

To manage environments use [configurations](https://cloud.google.com/sdk/docs/configurations).
These scritps will not override the configurations you are in and will display the current configuation when run.

Add the following to your `.profile`:

```
export GUSER=<replicated-email-user-name>
source $HOME/.gcommands.sh
```
