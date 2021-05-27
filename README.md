Kubernetes kubeconfig generator
===============================

Main difference of this generator script is the possibility to create kubeconfig for named users and groups defined per corresponding ClusterRoleBinding and RoleBinding K8S resources in opposite to the kubeconfig for a ServiceAccount as many of the generators across Github do.

Usage
=====

Run `./create_kubeconfig.sh` without parameters to see the help message.

**TL;DR**

```bash
./create_kubeconfig.sh some-user some-group
```

Generated kubeconfig will be valid for 5 years, unless cluster CA expires earlier

**Full example**

* Place cluster certification authority key `ca.key` to the same directory with the script. Key could be obtained from any K8S master node at `/etc/kubernetes/ssl/ca.key`

* Create example RoleBinding. It will give admin access to the `example-ns` namespace for any kubeconfig with the group `namespace-admins`:
  ```bash
  kubectl apply -f namespace-admins-rb.yaml
  ```

* Create kubeconfig for the group `namespace-admins`, user name could be whatever because we did not use User subject in our example RoleBinding:
  ```bash
  ./create_kubeconfig.sh happyuser namespace-admins > kubeconfig
  ```

* Done! Now you can use generated `kubeconfig` file as usual. For example by moving it to the `~/.kube/config` or setting to the env with `export KUBECONFIG=kubeconfig`
