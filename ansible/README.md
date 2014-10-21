stv3-config
==============

Configuration playbooks for StackTach.v3 deployments

Assumes an inventory value that has nodes or groups that start with "stv3-api" or "stv3-workers".

Execution would look like:

```bash
ansible-playbook -i stv3-workers01.region.example.com, stv3.yaml -c local -vv
```

Assumes a stv3-db setup already exists.
