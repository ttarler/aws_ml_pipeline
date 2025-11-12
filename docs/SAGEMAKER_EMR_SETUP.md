# SageMaker Notebook Instance - Manual EMR Connection Setup

Since the notebook instance is configured in a private subnet by default, automatic package installation via lifecycle configuration is disabled to prevent timeout errors during notebook startup.

## Internet Access Configuration

The SageMaker notebook instance internet access is controlled by the `sagemaker_notebook_direct_internet_access` variable:

- **"Disabled" (default, recommended)**: Notebook is deployed in a private subnet and accesses the internet via NAT Gateway. This is more secure and follows AWS best practices.
- **"Enabled"**: Notebook is deployed with a public IP and direct internet access. Less secure but can be used for testing.

With the NAT Gateway enabled (`enable_nat_gateway = true`), notebooks in private subnets can install packages from PyPI and access external resources.

## Manual Setup Steps

After your SageMaker notebook instance launches, follow these steps to connect to EMR:

### 1. Open the notebook instance

Navigate to SageMaker in AWS Console and open your notebook instance (or use the URL from `terraform output`).

### 2. Open a terminal

In JupyterLab, open a new terminal from the Launcher.

### 3. Install Sparkmagic

With NAT Gateway enabled (default configuration), your notebook has internet access to install packages:

```bash
# Switch to the Python 3 environment
source activate python3

# Install sparkmagic
pip install sparkmagic

# Install kernel specs
cd $(pip show sparkmagic | grep Location | cut -d' ' -f2)
jupyter-kernelspec install sparkmagic/kernels/pysparkkernel --user
jupyter-kernelspec install sparkmagic/kernels/sparkkernel --user
jupyter-kernelspec install sparkmagic/kernels/sparkrkernel --user
```

### 4. Configure Sparkmagic for EMR

Get your EMR master DNS from Terraform:
```bash
terraform output emr_master_public_dns
```

Create the Sparkmagic configuration:

```bash
mkdir -p ~/.sparkmagic

cat > ~/.sparkmagic/config.json <<EOF
{
  "kernel_python_credentials" : {
    "username": "",
    "password": "",
    "url": "http://YOUR-EMR-MASTER-DNS:8998",
    "auth": "None"
  },
  "kernel_scala_credentials" : {
    "username": "",
    "password": "",
    "url": "http://YOUR-EMR-MASTER-DNS:8998",
    "auth": "None"
  },
  "custom_headers" : {
    "X-Requested-By": "livy"
  },
  "session_configs" : {
    "driverMemory": "1000M",
    "executorCores": 2
  }
}
EOF
```

Replace `YOUR-EMR-MASTER-DNS` with the actual DNS from the terraform output.

### 5. Test the connection

Create a new notebook and select the PySpark kernel. Run:

```python
%%info
```

This should show your Spark session information if the connection is successful.

## Alternative: Use SageMaker Studio

SageMaker Studio (not the notebook instance) provides better integration with EMR and doesn't require manual configuration. Access it via the domain URL from terraform outputs.

## Troubleshooting

**Timeout errors during notebook launch:**
- The lifecycle configuration is disabled by default
- If you see timeout errors, ensure lifecycle config is not enabled in the notebook instance

**Can't reach EMR:**
- Check security groups allow traffic from SageMaker SG to EMR master on port 8998
- Verify EMR Livy service is running: `ssh hadoop@emr-master-dns "sudo systemctl status livy-server"`

**Can't install packages:**
- Ensure NAT Gateway is enabled: `terraform output nat_gateway_public_ip`
- Check route table has 0.0.0.0/0 → NAT Gateway
- Verify security groups allow HTTPS/HTTP egress
