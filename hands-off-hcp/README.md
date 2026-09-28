# Hands Off: HCP Terraform + Azure Monitoring

The last project of my 8-project Terraform lab on Azure. Until now Terraform always ran on something I set up myself, either Cloud Shell or a GitHub Actions runner. This time I let HCP Terraform handle the state, the runs and the credentials, and used it to deploy a VM with CPU monitoring. The VM has no public IP, and an alert emails me when its CPU gets too high.

## What I did

I swapped the `backend "azurerm"` block for a `cloud {}` block, ran `terraform login` and `init`, and the state moved into an HCP workspace. The Azure credentials went into a variable set so the runs log in through OIDC, which means there's no secret stored anywhere. The SSH public key went into the workspace as a variable.

The config uses a small network module (in `modules/network`) and adds a Linux VM, a Log Analytics workspace, an action group and a CPU alert. Later I dropped the alert threshold from 70% to 60% through a pull request, mostly to watch HCP plan the change before anything was applied.

## What I learned

HCP workspaces and CLI workspaces sound like the same thing, but they aren't. A CLI workspace (`terraform workspace new dev`) is just another state for the same config. In HCP a workspace has its own state, variables and run history, and it sits inside a project inside an organization.

You can't keep both a `cloud {}` block and a `backend {}` block. Moving from one to the other is just a state migration through `terraform init`, the same way you'd move local state to a remote backend.

The biggest change for me was realising the runs don't happen on my machine anymore. `terraform plan` looks the same in Cloud Shell, but it actually runs on HCP's servers, and they can't see my environment variables, my `az login` or my `~/.ssh`. Everything has to be passed in. Azure credentials go in as environment variables, and anything from a `variable` block goes in as a Terraform variable. Pick the wrong type and the run fails.

OIDC needed two federated credentials this time, because HCP uses a different subject for the plan step and the apply step. The subject string has to match exactly, capital letters included.

Earlier in the lab I built state locking, plan artifacts, approvals and a safe destroy by hand in GitHub Actions YAML. HCP has all of that built in: a run queue, a Confirm & apply button, every old state version kept, and plans posted on pull requests automatically. That last kind of plan, a speculative plan, can never be applied.

The CPU alert doesn't need any agent on the VM, because Azure collects `Percentage CPU` from the host. The Log Analytics workspace is different: it stays empty until you install the Azure Monitor Agent and add a data collection rule. Mine is empty for now, and that's the next step.

The alert fires only when the average CPU over 5 minutes is above 60%, so short spikes don't count. My VM has 2 vCPUs, so a single `yes` process only reaches about 50% overall. You need one per vCPU to trigger it.

Because it's a single VM, I can reference it as `azurerm_linux_virtual_machine.vm_1`. If I'd created it with `for_each`, the alert would have needed `vm["name"]`.

## Architecture

```
HCP Terraform: organization -> project -> workspace (state, runs, variables)
  variable set (env): ARM_* + TFC_AZURE_*  -> OIDC, no stored secret
  workspace var (tf): admin_public_key

rg-tf-08-dev-uks (UK South)
├── vnet-tf08 10.40.0.0/16 -> snet-app 10.40.1.0/24 + NSG   (module.network)
├── vm-1  Standard_D2als_v6, Ubuntu 24.04, private IP only
├── log-tg08          Log Analytics, 30 days
├── ag-tf08-ops       action group -> email
└── alert-vm-1-cpu70  avg CPU > 60% over 5 min -> ag-tf08-ops
```

## Run it

```bash
terraform login && terraform init
terraform plan && terraform apply     # runs on HCP, not locally

# load both vCPUs, wait ~10 min for the alert email, then stop
az vm run-command invoke -g rg-tf-08-dev-uks -n vm-1 --command-id RunShellScript \
  --scripts "for i in 1 2; do nohup sh -c 'yes > /dev/null' >/dev/null 2>&1 & done; sleep 1"
az vm run-command invoke -g rg-tf-08-dev-uks -n vm-1 --command-id RunShellScript --scripts "pkill yes"
```

Before the first run, set up the variable set, the two federated credentials and `admin_public_key`, and put your own email in place of `<your-email>` in `main.tf`.

## Screenshots

<!-- Add screenshots to ./screenshots/ and embed them here -->
