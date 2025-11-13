# SageMaker Studio Spaces with R and RSpark Kernels

This guide explains how to use the SageMaker Studio Spaces configured with R and RSpark kernels for both general purpose CPU and accelerated compute (GPU) workloads.

## Overview

The infrastructure automatically creates two Space templates:

1. **General Purpose Template**: Optimized for CPU-based workloads
2. **Accelerated Compute Template**: Optimized for GPU-accelerated workloads

Both templates include:
- **R Kernel**: Standard R programming environment
- **RSpark Kernel**: R with Spark integration for distributed computing
- **Python Kernels**: Standard Python data science environment
- **EMR Connectivity**: Pre-configured for Apache Livy/Spark connections

## Available Kernels

### 1. R Kernel
- **Kernel Name**: `ir`
- **Display Name**: R
- **Use Case**: Statistical computing, data analysis, visualization
- **Best For**: General purpose R workloads, RStudio compatibility

### 2. RSpark Kernel
- **Kernel Name**: `sparkr`
- **Display Name**: R with Spark
- **Use Case**: Large-scale data processing with SparkR
- **Best For**: Distributed R computations on EMR clusters

### 3. Python Kernels (Built-in)
- **Data Science**: Python 3 with scientific libraries
- **PySpark**: Python with Spark integration

## Instance Types by Space Template

### General Purpose CPU Instances

Suitable for:
- Standard data analysis
- Model training (small to medium datasets)
- Data preprocessing
- Exploratory data analysis

**Available Instance Types:**
- `ml.t3.medium` to `ml.t3.2xlarge` - Burstable performance
- `ml.m5.large` to `ml.m5.12xlarge` - Balanced compute/memory
- `ml.c5.large` to `ml.c5.9xlarge` - Compute optimized

**Default**: `ml.m5.large` (2 vCPUs, 8 GB RAM)

### Accelerated Compute (GPU) Instances

Suitable for:
- Deep learning model training
- Large-scale neural networks
- GPU-accelerated computations
- Computer vision / NLP workloads

**Available Instance Types:**
- `ml.g4dn.xlarge` to `ml.g4dn.16xlarge` - NVIDIA T4 GPUs
- `ml.g5.xlarge` to `ml.g5.16xlarge` - NVIDIA A10G GPUs
- `ml.p3.2xlarge` to `ml.p3.16xlarge` - NVIDIA V100 GPUs

**Default**: `ml.g4dn.xlarge` (1 GPU, 4 vCPUs, 16 GB RAM)

**Note**: GPU instances may not be available in all GovCloud regions. Check quotas with:
```bash
./scripts/check-sagemaker-instance-types.sh us-gov-west-1
```

## Creating a Space

### Via AWS Console

1. Navigate to **SageMaker** in AWS GovCloud Console
2. Click **Domains** → Select your domain
3. Click **Spaces** → **Create space**
4. Choose a template:
   - **general-purpose-template** for CPU workloads
   - **accelerated-compute-template** for GPU workloads
5. Customize space settings if needed
6. Click **Create space**

### Via AWS CLI

**Create General Purpose Space:**
```bash
aws sagemaker create-space \
  --domain-id <your-domain-id> \
  --space-name my-r-workspace \
  --space-settings file://general-purpose-space-settings.json \
  --region us-gov-west-1
```

**Create Accelerated Compute Space:**
```bash
aws sagemaker create-space \
  --domain-id <your-domain-id> \
  --space-name my-gpu-workspace \
  --space-settings file://accelerated-compute-space-settings.json \
  --region us-gov-west-1
```

## Using R Kernel

### 1. Launch Space with R Kernel

1. Open SageMaker Studio
2. Navigate to your space
3. Click **Run space**
4. Select **R** from available kernels
5. Click **Select**

### 2. Install R Packages

```r
# Install packages from CRAN
install.packages("ggplot2")
install.packages("dplyr")
install.packages("tidyr")

# Install from Bioconductor
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("GenomicRanges")

# Load libraries
library(ggplot2)
library(dplyr)
```

### 3. Access S3 Data

```r
# Using aws.s3 package
install.packages("aws.s3")
library(aws.s3)

# Read CSV from S3
bucket <- "your-landing-zone-bucket"
data <- s3read_using(read.csv, object = "s3://bucket-name/data/file.csv")

# Write to S3
s3write_using(data, FUN = write.csv,
              object = "s3://bucket-name/output/result.csv")
```

### 4. Data Visualization

```r
library(ggplot2)

# Create visualization
ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(aes(color = factor(cyl))) +
  geom_smooth(method = "lm") +
  theme_minimal() +
  labs(title = "MPG vs Weight by Cylinders")
```

## Using RSpark Kernel

### 1. Connect to EMR Cluster

The RSpark kernel is pre-configured to connect to your EMR cluster via Apache Livy.

```r
# The connection is established automatically via the lifecycle config
# Check Spark session
library(SparkR)

# Initialize Spark session (if not auto-connected)
sparkR.session(master = "yarn",
               appName = "RSparkExample",
               sparkConfig = list(spark.executor.memory = "2g"))
```

### 2. Read Data with SparkR

```r
library(SparkR)

# Read CSV from S3
df <- read.df("s3://your-bucket/data/large-dataset.csv",
              source = "csv",
              header = "true",
              inferSchema = "true")

# Show schema
printSchema(df)

# Display first rows
showDF(df, numRows = 10)
```

### 3. Distributed Data Processing

```r
# Filter and aggregate
result <- df %>%
  filter(df$value > 100) %>%
  groupBy(df$category) %>%
  agg(avg(df$amount), count(df$id))

# Collect results to local R dataframe
local_result <- collect(result)

# Continue with local R operations
library(ggplot2)
ggplot(local_result, aes(x = category, y = `avg(amount)`)) +
  geom_bar(stat = "identity")
```

### 4. Machine Learning with SparkR

```r
library(SparkR)

# Prepare data
training <- df %>% select("features", "label")

# Train a model
model <- spark.glm(label ~ .,
                   data = training,
                   family = "gaussian")

# Make predictions
predictions <- predict(model, training)

# Evaluate
showDF(predictions, numRows = 20)
```

## Switching Between Instance Types

You can change instance types for a space without recreating it:

### Via Console
1. Stop the space (if running)
2. Edit space settings
3. Change instance type under **Kernel Gateway App Settings**
4. Save changes
5. Restart space

### Via CLI
```bash
aws sagemaker update-space \
  --domain-id <domain-id> \
  --space-name <space-name> \
  --space-settings '{"KernelGatewayAppSettings":{"DefaultResourceSpec":{"InstanceType":"ml.m5.2xlarge"}}}' \
  --region us-gov-west-1
```

## Best Practices

### 1. Cost Optimization
- **Stop spaces when not in use** - Spaces incur charges while running
- **Start with smaller instances** - Scale up only when needed
- **Use general purpose for development** - Reserve GPU for training/inference
- **Monitor usage**: Check CloudWatch metrics for resource utilization

### 2. Performance Optimization
- **CPU workloads**: Use `ml.m5.*` or `ml.c5.*` instances
- **Memory-intensive**: Use `ml.m5.*` instances with larger sizes
- **GPU workloads**: Start with `ml.g4dn.xlarge`, scale to `ml.g5.*` for better performance
- **Large datasets**: Use RSpark kernel with EMR for distributed processing

### 3. Development Workflow
```
Development → Testing → Production

ml.t3.medium → ml.m5.xlarge → ml.g4dn.xlarge
(General)      (General)       (Accelerated)
```

### 4. Package Management
- Install packages in user space (not system-wide)
- Consider creating custom Docker images for repeated use
- Use `.Rprofile` for commonly used packages
- Cache package installations in S3

## Troubleshooting

### R Kernel Not Available
**Problem**: R kernel doesn't appear in kernel list

**Solution**:
1. Check app image config exists:
   ```bash
   terraform output sagemaker_r_kernel_config
   ```
2. Verify space template was created:
   ```bash
   terraform output sagemaker_general_purpose_space
   ```
3. Recreate space using the template

### RSpark Connection Fails
**Problem**: Cannot connect to EMR via Livy

**Solutions**:
1. Verify EMR cluster is running:
   ```bash
   terraform output emr_cluster_id
   aws emr describe-cluster --cluster-id <cluster-id> --region us-gov-west-1
   ```

2. Check security group rules allow SageMaker → EMR on port 8998:
   ```bash
   # This should already be configured in the infrastructure
   ```

3. Verify lifecycle config is attached:
   ```bash
   aws sagemaker describe-space \
     --domain-id <domain-id> \
     --space-name <space-name> \
     --region us-gov-west-1
   ```

### Package Installation Fails
**Problem**: Cannot install R packages

**Solutions**:
1. Check NAT Gateway is enabled (for internet access):
   ```bash
   terraform output nat_gateway_public_ip
   ```

2. Verify network connectivity from space
3. Use a CRAN mirror if default is slow:
   ```r
   options(repos = c(CRAN = "https://cloud.r-project.org"))
   install.packages("package-name")
   ```

### Out of Memory Errors
**Problem**: R processes running out of memory

**Solutions**:
1. Upgrade to larger instance type (more RAM)
2. Use data.table or arrow for memory efficiency
3. Switch to RSpark for distributed processing
4. Process data in chunks

## Instance Type Selection Guide

| Workload Type | Recommended Instance | vCPUs | RAM | GPU | Hourly Cost* |
|---------------|---------------------|-------|-----|-----|--------------|
| Light development | ml.t3.medium | 2 | 4 GB | - | Low |
| Standard analysis | ml.m5.large | 2 | 8 GB | - | Low |
| Large datasets (CPU) | ml.m5.4xlarge | 16 | 64 GB | - | Medium |
| Deep learning dev | ml.g4dn.xlarge | 4 | 16 GB | 1 | Medium |
| Production training | ml.g5.4xlarge | 16 | 64 GB | 1 | High |
| Large-scale GPU | ml.p3.8xlarge | 32 | 244 GB | 4 | Very High |

*Check current pricing in GovCloud region

## Additional Resources

- [SparkR Documentation](https://spark.apache.org/docs/latest/sparkr.html)
- [SageMaker Studio Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/studio.html)
- [R on AWS](https://aws.amazon.com/blogs/opensource/r-on-aws/)
- [EMR with SageMaker](./SAGEMAKER_EMR_SETUP.md)

## Getting Help

Check available instance types and quotas:
```bash
./scripts/check-sagemaker-instance-types.sh us-gov-west-1
```

List your spaces:
```bash
aws sagemaker list-spaces \
  --domain-id-equals $(terraform output -raw sagemaker_domain_id) \
  --region us-gov-west-1
```

View space details:
```bash
aws sagemaker describe-space \
  --domain-id <domain-id> \
  --space-name <space-name> \
  --region us-gov-west-1
```
