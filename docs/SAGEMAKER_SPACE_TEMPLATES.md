# SageMaker Studio Space Templates

## Overview

This infrastructure automatically configures SageMaker Studio with pre-configured space templates that include R kernel support and options for both general purpose CPU and accelerated GPU compute instances.

## Space Templates

### 1. General Purpose CPU Template

**Name**: `general-purpose-cpu-template`

**Configuration**:
- **Instance Type**: ml.t3.medium (default)
- **Image**: SageMaker Distribution (CPU)
- **Available Instance Range**: ml.t3.medium to ml.m5.24xlarge

**Installed Kernels**:
- Python 3 (with scientific libraries)
- R (with IRkernel)
- PySpark
- SparkR (if EMR configured)
- Neptune Graph (if Neptune enabled)

**Pre-installed R Packages**:
- `r-base` - R language core
- `r-irkernel` - R kernel for Jupyter
- `r-essentials` - Essential R packages collection
- `r-tidyverse` - Data manipulation and visualization
- `r-ggplot2` - Advanced plotting
- `r-caret` - Machine learning framework
- `r-data.table` - High-performance data manipulation
- `r-dplyr` - Data transformation
- `r-devtools` - R package development tools
- `r-shiny` - Interactive web applications
- `r-rmarkdown` - Dynamic documents
- `randomForest` - Random forest algorithm
- `xgboost` - Gradient boosting
- `mlr3` - Machine learning framework
- `keras` - Deep learning interface
- `SparkR` - R interface to Apache Spark (if EMR configured)

**Use Cases**:
- Data analysis and exploration
- Statistical computing
- R programming and development
- Data visualization
- Light machine learning workloads
- Cost-effective development and testing

**Cost**: Lower cost, suitable for most data science tasks

### 2. Accelerated Compute GPU Template

**Name**: `accelerated-compute-gpu-template`

**Configuration**:
- **Instance Type**: ml.g4dn.xlarge (default)
- **Image**: SageMaker Distribution (GPU)
- **Available Instance Range**: ml.g4dn.xlarge to ml.p3.16xlarge

**Installed Kernels**:
- Python 3 (with scientific libraries + GPU support)
- R (with IRkernel + GPU packages)
- PySpark
- SparkR (if EMR configured)
- Neptune Graph (if Neptune enabled)

**Pre-installed R Packages**:
- All packages from General Purpose template
- GPU-enabled versions where applicable
- TensorFlow and Keras with GPU support

**Use Cases**:
- Deep learning model training
- Large-scale machine learning
- GPU-accelerated data processing
- Computer vision workloads
- Natural language processing
- High-performance R computations

**Cost**: Higher cost, recommended for GPU-intensive workloads only

## Instance Type Selection Guide

### General Purpose CPU Instances

| Instance Type | vCPUs | Memory | Use Case | Hourly Cost* |
|--------------|-------|--------|----------|-------------|
| ml.t3.medium | 2 | 4 GB | Development, light analysis | Low |
| ml.t3.large | 2 | 8 GB | Development, testing | Low |
| ml.t3.xlarge | 4 | 16 GB | Medium datasets | Low-Medium |
| ml.m5.large | 2 | 8 GB | Production, balanced workload | Medium |
| ml.m5.xlarge | 4 | 16 GB | Medium production workloads | Medium |
| ml.m5.2xlarge | 8 | 32 GB | Large datasets | Medium-High |
| ml.m5.4xlarge | 16 | 64 GB | Very large datasets | High |
| ml.m5.12xlarge | 48 | 192 GB | Enterprise-scale analysis | Very High |

### Accelerated Compute GPU Instances

| Instance Type | vCPUs | GPU Memory | GPUs | Use Case | Hourly Cost* |
|--------------|-------|------------|------|----------|-------------|
| ml.g4dn.xlarge | 4 | 16 GB | 1 (T4) | Development, small models | Medium |
| ml.g4dn.2xlarge | 8 | 16 GB | 1 (T4) | Medium models | Medium-High |
| ml.g5.xlarge | 4 | 24 GB | 1 (A10G) | Production inference | High |
| ml.g5.2xlarge | 8 | 24 GB | 1 (A10G) | Production training | High |
| ml.p3.2xlarge | 8 | 16 GB | 1 (V100) | Large-scale training | Very High |
| ml.p3.8xlarge | 32 | 64 GB | 4 (V100) | Multi-GPU training | Very High |
| ml.p3.16xlarge | 64 | 128 GB | 8 (V100) | Enterprise deep learning | Extremely High |

*Check current AWS GovCloud pricing for exact costs

## How Space Templates Work

### 1. Domain-Level Configuration

The SageMaker domain is configured with default space settings that include:

```hcl
default_space_settings {
  # JupyterLab settings with R kernel support
  jupyter_lab_app_settings {
    default_resource_spec {
      instance_type       = "ml.t3.medium"
      sagemaker_image_arn = "sagemaker-distribution-cpu"
    }
  }

  # Kernel Gateway with lifecycle config for R installation
  kernel_gateway_app_settings {
    lifecycle_config_arns = [r_and_spark_setup]
  }
}
```

### 2. Space Template Resources

Two pre-configured space templates are created:

- `general-purpose-cpu-template` - For CPU workloads
- `accelerated-compute-gpu-template` - For GPU workloads

Users can create new spaces based on these templates.

### 3. Automatic Kernel Installation

When a space is launched, a lifecycle configuration automatically:

1. Installs R base and IRkernel via conda
2. Registers R kernel with Jupyter
3. Installs essential R packages
4. Installs PySpark and SparkMagic
5. Configures EMR connectivity (if EMR enabled)
6. Installs Neptune libraries (if Neptune enabled)
7. Verifies all kernel installations

## Using Space Templates

### Create a Space from Console

1. **Open SageMaker Studio**:
   - Navigate to AWS Console → SageMaker → Domains
   - Click on your domain name
   - Click "Launch" → "Studio"

2. **Create New Space**:
   - In Studio, click "Spaces" in left sidebar
   - Click "Create space"

3. **Configure Space**:
   - **Name**: Enter a descriptive name (e.g., `r-analytics-workspace`)
   - **Space template**: Choose one:
     - `general-purpose-cpu-template` - For R and data analysis
     - `accelerated-compute-gpu-template` - For deep learning
   - **Instance type**: (Optional) Change from default
   - Click "Create space"

4. **Launch Space**:
   - Click "Run space"
   - Wait for JupyterLab to load
   - R kernel is automatically available

### Create a Space via CLI

```bash
# Get domain ID
DOMAIN_ID=$(terraform output -raw sagemaker_domain_id)

# Create CPU-based space
aws sagemaker create-space \
    --domain-id $DOMAIN_ID \
    --space-name r-analytics-workspace \
    --region us-gov-west-1

# Create GPU-based space
aws sagemaker create-space \
    --domain-id $DOMAIN_ID \
    --space-name gpu-training-workspace \
    --region us-gov-west-1

# Launch the space
aws sagemaker create-app \
    --domain-id $DOMAIN_ID \
    --space-name r-analytics-workspace \
    --app-type JupyterLab \
    --app-name default \
    --region us-gov-west-1
```

## Using R in Your Space

### Basic R Usage

Once your space is running, select "R" from the kernel dropdown in JupyterLab:

```r
# Load libraries (pre-installed)
library(tidyverse)
library(ggplot2)
library(caret)

# Read data from S3
data <- read.csv("s3://your-bucket/data/dataset.csv")

# Data manipulation
summary <- data %>%
  filter(value > 100) %>%
  group_by(category) %>%
  summarize(
    mean_value = mean(value),
    count = n()
  )

# Visualization
ggplot(data, aes(x = category, y = value)) +
  geom_boxplot() +
  theme_minimal() +
  labs(title = "Value Distribution by Category")
```

### Machine Learning in R

```r
library(caret)
library(randomForest)

# Load dataset
data <- read.csv("s3://your-bucket/ml-data.csv")

# Split data
set.seed(123)
trainIndex <- createDataPartition(data$target, p = 0.8, list = FALSE)
trainData <- data[trainIndex, ]
testData <- data[-trainIndex, ]

# Train model
model <- train(
  target ~ .,
  data = trainData,
  method = "rf",
  trControl = trainControl(method = "cv", number = 5)
)

# Predictions
predictions <- predict(model, testData)

# Evaluate
confusionMatrix(predictions, testData$target)
```

### Using R with Spark (EMR)

If EMR is configured, SparkR kernel is available:

```r
library(SparkR)

# Connect to EMR via Livy (automatic)
sparkR.session()

# Read large dataset from S3 using Spark
df <- read.df(
  "s3://your-bucket/large-dataset.parquet",
  source = "parquet"
)

# Distributed processing
result <- df %>%
  filter(df$value > 1000) %>%
  groupBy(df$category) %>%
  agg(
    avg(df$amount),
    count(df$id)
  )

# Collect results to local R
local_result <- collect(result)

# Visualize with ggplot2
ggplot(local_result, aes(x = category, y = avg_amount)) +
  geom_bar(stat = "identity")
```

## Changing Instance Types

### From Console

1. **Stop the space app**:
   - Go to Spaces → Your space
   - Click "Stop"

2. **Update instance type**:
   - Click "Space settings"
   - Select new instance type
   - Click "Save"

3. **Restart the app**:
   - Click "Run space"

### From CLI

```bash
# Update space settings
aws sagemaker update-space \
    --domain-id $DOMAIN_ID \
    --space-name r-analytics-workspace \
    --space-settings '{
      "JupyterLabAppSettings": {
        "DefaultResourceSpec": {
          "InstanceType": "ml.m5.xlarge"
        }
      }
    }' \
    --region us-gov-west-1
```

## Cost Optimization

### Best Practices

1. **Use T3 instances for development**:
   - ml.t3.medium for light work
   - ml.t3.large for medium datasets
   - Lower cost, burstable performance

2. **Use M5 instances for production**:
   - ml.m5.large for consistent workloads
   - ml.m5.xlarge+ for large datasets
   - Predictable performance

3. **Use GPU instances sparingly**:
   - Only for GPU-accelerated workloads
   - Stop when not in use
   - Consider spot instances for training

4. **Stop spaces when not in use**:
   ```bash
   # Stop space app
   aws sagemaker delete-app \
       --domain-id $DOMAIN_ID \
       --space-name r-analytics-workspace \
       --app-type JupyterLab \
       --app-name default \
       --region us-gov-west-1
   ```

5. **Monitor costs**:
   - Use AWS Cost Explorer
   - Set up billing alarms
   - Tag spaces by project/team

## Troubleshooting

### R Kernel Not Available

If R kernel doesn't appear:

1. **Check lifecycle config execution**:
   ```bash
   # View lifecycle config logs
   aws sagemaker describe-app \
       --domain-id $DOMAIN_ID \
       --space-name your-space \
       --app-type KernelGateway \
       --app-name default \
       --region us-gov-west-1
   ```

2. **Manually verify R installation**:
   - Open Terminal in JupyterLab
   - Run: `jupyter kernelspec list`
   - Check for `ir` kernel

3. **Reinstall R kernel**:
   ```bash
   # In JupyterLab terminal
   conda install -y -c conda-forge r-base r-irkernel
   R -e "IRkernel::installspec(user = FALSE)"
   ```

### Space Won't Start

**Check instance availability**:
- Some GPU instances may not be available in GovCloud
- Try a different instance type
- Check AWS Service Quotas

### Package Installation Errors

**If R packages fail to install**:

```r
# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org/"))

# Install with dependencies
install.packages("packagename", dependencies = TRUE)

# For system-level packages, use terminal:
# conda install -c conda-forge r-packagename
```

## Related Documentation

- [SageMaker Spaces with R and RSpark Kernels](SAGEMAKER_SPACES_KERNELS.md)
- [Main README - SageMaker Configuration](../README.md#2-amazon-sagemaker)
- [Neptune Setup Guide](NEPTUNE_SETUP.md)
- [AWS SageMaker Studio Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/studio.html)
