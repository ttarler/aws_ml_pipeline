# AWS Neptune Graph Database Setup and Usage

This guide explains how to use the AWS Neptune graph database cluster with SageMaker and EMR for graph analytics and machine learning workloads.

## Overview

AWS Neptune is a fully managed graph database service that supports both Property Graph and RDF graph models. The infrastructure provides:

- **Neptune Cluster**: Highly available graph database
- **SageMaker Integration**: Neptune graph notebook kernel for graph analytics
- **EMR Connectivity**: Distributed graph processing with Spark
- **Security**: Private VPC deployment with IAM authentication
- **Backup & Recovery**: Automated backups with configurable retention

## Architecture

```
┌─────────────────────────────────────────────────┐
│              SageMaker Studio                    │
│  ┌──────────────────────────────────────────┐  │
│  │ Neptune Graph Notebook Kernel             │  │
│  │ - Gremlin (Property Graph)               │  │
│  │ - SPARQL (RDF)                          │  │
│  └──────────────┬───────────────────────────┘  │
│                 │ Port 8182                     │
└─────────────────┼───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│          Neptune Cluster (Private VPC)           │
│  ┌────────────────┐      ┌────────────────┐    │
│  │ Primary Instance│      │ Read Replica   │    │
│  │ db.r5.large     │◄────►│ (Optional)     │    │
│  └────────────────┘      └────────────────┘    │
│         │                                        │
│         └─── Automated backups to S3            │
└──────────────▲──────────────────────────────────┘
               │ Port 8182
┌──────────────┴──────────────────────────────────┐
│              EMR Cluster                         │
│  - Spark GraphX for distributed graph processing │
│  - Bulk loading from S3 to Neptune              │
└──────────────────────────────────────────────────┘
```

## Enabling Neptune

### In terraform.tfvars:

```hcl
# Enable Neptune
enable_neptune                  = true
neptune_instance_class          = "db.r5.large"
neptune_instance_count          = 1  # Use 2+ for high availability
neptune_backup_retention_period = 7
neptune_skip_final_snapshot     = false
```

### Deploy:

```bash
terraform init  # Required after adding Neptune module
terraform apply
```

### Get Connection Information:

```bash
# Neptune cluster endpoint
terraform output neptune_cluster_endpoint

# Example output: my-project-neptune-cluster.cluster-xxxxx.us-gov-west-1.neptune.amazonaws.com
```

## Neptune Instance Types (GovCloud Compatible)

| Instance Type | vCPUs | RAM | Use Case | Monthly Cost* |
|--------------|-------|-----|----------|---------------|
| db.r5.large | 2 | 16 GB | Development/Testing | Low |
| db.r5.xlarge | 4 | 32 GB | Small production | Medium |
| db.r5.2xlarge | 8 | 64 GB | Medium production | Medium-High |
| db.r5.4xlarge | 16 | 128 GB | Large production | High |
| db.r5.8xlarge | 32 | 256 GB | Very large graphs | Very High |
| db.r5.12xlarge | 48 | 384 GB | Enterprise scale | Very High |

*Check current GovCloud pricing

## Using Neptune with SageMaker

### 1. Launch Space with Neptune Kernel

1. Open SageMaker Studio
2. Click **Spaces** → **Create space**
3. Select **general-purpose-template** or **accelerated-compute-template**
4. Launch space
5. Select **Neptune Graph (Python 3)** kernel

### 2. Install Neptune Python Libraries

```python
# Install gremlinpython for Property Graph queries
!pip install gremlinpython

# Install SPARQLWrapper for RDF queries
!pip install SPARQLWrapper

# Install neptune-python-utils for bulk loading
!pip install neptune-python-utils
```

### 3. Connect to Neptune (Gremlin/Property Graph)

```python
from gremlin_python import statics
from gremlin_python.structure.graph import Graph
from gremlin_python.process.graph_traversal import __
from gremlin_python.driver.driver_remote_connection import DriverRemoteConnection

# Get Neptune endpoint from Terraform output
neptune_endpoint = "your-neptune-cluster.cluster-xxxxx.us-gov-west-1.neptune.amazonaws.com"
neptune_port = 8182

# Create connection
graph = Graph()
connection = DriverRemoteConnection(
    f'wss://{neptune_endpoint}:{neptune_port}/gremlin',
    'g'
)
g = graph.traversal().withRemote(connection)

# Verify connection
print("Connected to Neptune!")
```

### 4. Basic Gremlin Queries

```python
# Add vertices (nodes)
v1 = g.addV('person').property('name', 'Alice').property('age', 30).next()
v2 = g.addV('person').property('name', 'Bob').property('age', 35).next()
v3 = g.addV('company').property('name', 'TechCorp').next()

# Add edges (relationships)
g.V(v1).addE('knows').to(v2).property('since', 2015).iterate()
g.V(v1).addE('works_at').to(v3).property('role', 'Engineer').iterate()
g.V(v2).addE('works_at').to(v3).property('role', 'Manager').iterate()

# Query: Find all people
people = g.V().hasLabel('person').valueMap().toList()
print(f"All people: {people}")

# Query: Find Alice's coworkers
coworkers = g.V().has('person', 'name', 'Alice')\
    .out('works_at').in_('works_at')\
    .where(__.neq(v1))\
    .values('name').toList()
print(f"Alice's coworkers: {coworkers}")

# Query: Graph traversal - who knows who
paths = g.V().has('person', 'name', 'Alice')\
    .repeat(__.out('knows')).times(2)\
    .path().by('name').toList()
print(f"Connection paths from Alice: {paths}")

# Close connection
connection.close()
```

### 5. SPARQL Queries (RDF)

```python
from SPARQLWrapper import SPARQLWrapper, JSON

# Neptune SPARQL endpoint
sparql_endpoint = f"https://{neptune_endpoint}:{neptune_port}/sparql"
sparql = SPARQLWrapper(sparql_endpoint)

# Insert RDF triples
insert_query = """
PREFIX ex: <http://example.org/>
INSERT DATA {
    ex:Alice ex:knows ex:Bob .
    ex:Alice ex:age "30"^^<http://www.w3.org/2001/XMLSchema#integer> .
    ex:Bob ex:age "35"^^<http://www.w3.org/2001/XMLSchema#integer> .
}
"""
sparql.setQuery(insert_query)
sparql.setMethod('POST')
sparql.query()

# Query RDF data
select_query = """
PREFIX ex: <http://example.org/>
SELECT ?person ?age
WHERE {
    ?person ex:age ?age .
}
"""
sparql.setQuery(select_query)
sparql.setReturnFormat(JSON)
results = sparql.query().convert()

for result in results["results"]["bindings"]:
    print(f"Person: {result['person']['value']}, Age: {result['age']['value']}")
```

## Using Neptune with EMR

### 1. Install Neptune Spark Connector

SSH to EMR master node and install:

```bash
ssh -i your-key.pem hadoop@<emr-master-dns>

# Install Neptune Spark connector
sudo pip3 install neptune-python-utils
```

### 2. Bulk Load from S3 to Neptune

```python
from pyspark.sql import SparkSession

# Create Spark session
spark = SparkSession.builder \
    .appName("NeptuneBulkLoad") \
    .getOrCreate()

# Read data from S3
df = spark.read.csv("s3://your-bucket/graph-data/nodes.csv", header=True)

# Transform to Neptune format
# Nodes CSV format: ~id, ~label, name, age
nodes_df = df.select("id", "label", "name", "age")
nodes_df.write.csv("s3://your-bucket/neptune-load/nodes/", mode="overwrite")

# Trigger Neptune bulk load
import requests

neptune_endpoint = "your-neptune-endpoint"
load_url = f"https://{neptune_endpoint}:8182/loader"

payload = {
    "source": "s3://your-bucket/neptune-load/nodes/",
    "format": "csv",
    "iamRoleArn": "arn:aws-us-gov:iam::account-id:role/NeptuneLoadRole",
    "region": "us-gov-west-1",
    "failOnError": "FALSE"
}

response = requests.post(load_url, json=payload)
print(f"Load job ID: {response.json()['payload']['loadId']}")
```

### 3. Graph Analytics with Spark GraphX

```python
from pyspark import SparkContext
from pyspark.sql import SQLContext
from graphframes import GraphFrame

# Load graph from Neptune to Spark
from gremlinpython.structure.graph import Graph
from gremlin_python.driver.driver_remote_connection import DriverRemoteConnection

neptune_endpoint = "your-neptune-endpoint"

# Create Spark DataFrames from Neptune graph
# Vertices
vertices = spark.createDataFrame([
    ("Alice", "person", 30),
    ("Bob", "person", 35),
    ("TechCorp", "company", None)
], ["id", "label", "age"])

# Edges
edges = spark.createDataFrame([
    ("Alice", "Bob", "knows"),
    ("Alice", "TechCorp", "works_at"),
    ("Bob", "TechCorp", "works_at")
], ["src", "dst", "relationship"])

# Create GraphFrame
graph = GraphFrame(vertices, edges)

# Run PageRank
results = graph.pageRank(resetProbability=0.15, maxIter=10)
results.vertices.select("id", "pagerank").show()

# Find connected components
components = graph.connectedComponents()
components.select("id", "component").show()

# Triangle count
triangles = graph.triangleCount()
triangles.select("id", "count").show()
```

## Data Modeling Best Practices

### Property Graph (Gremlin)

```python
# Good: Use meaningful labels
g.addV('user').property('userId', '123').property('name', 'Alice')
g.addV('product').property('productId', 'ABC').property('name', 'Widget')
g.V().has('user', 'userId', '123')\
    .addE('purchased').to(__.V().has('product', 'productId', 'ABC'))\
    .property('date', '2025-01-15').property('amount', 29.99)

# Good: Index frequently queried properties
# (Neptune auto-indexes 'id' and labels)

# Good: Limit traversal depth
g.V().has('user', 'userId', '123')\
    .repeat(__.out('knows')).times(2).limit(100)  # Limit results
```

### RDF (SPARQL)

```sparql
# Good: Use clear URI patterns
PREFIX ex: <http://example.org/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

INSERT DATA {
    ex:user/123 rdf:type ex:User ;
                ex:name "Alice" ;
                ex:purchased ex:product/ABC .
}

# Good: Use LIMIT for large result sets
SELECT ?user ?name
WHERE {
    ?user rdf:type ex:User ;
          ex:name ?name .
}
LIMIT 100
```

## Backup and Recovery

### Automated Backups

Backups are automatic with configurable retention:

```hcl
neptune_backup_retention_period = 7  # Days
```

### Manual Snapshot

```bash
aws neptune create-db-cluster-snapshot \
    --db-cluster-identifier your-neptune-cluster \
    --db-cluster-snapshot-identifier manual-snapshot-2025-01-15 \
    --region us-gov-west-1
```

### Restore from Snapshot

```bash
aws neptune restore-db-cluster-from-snapshot \
    --db-cluster-identifier restored-neptune-cluster \
    --snapshot-identifier manual-snapshot-2025-01-15 \
    --engine neptune \
    --region us-gov-west-1
```

## Monitoring and Performance

### CloudWatch Metrics

Key metrics to monitor:

```bash
# View cluster metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Neptune \
    --metric-name CPUUtilization \
    --dimensions Name=DBClusterIdentifier,Value=your-neptune-cluster \
    --start-time 2025-01-15T00:00:00Z \
    --end-time 2025-01-15T23:59:59Z \
    --period 3600 \
    --statistics Average \
    --region us-gov-west-1
```

**Important Metrics:**
- `CPUUtilization` - Should be < 80%
- `FreeableMemory` - Monitor for memory pressure
- `Gremlin/SPARQLRequestsPerSec` - Query load
- `GremlinRequestsPerSec` - Gremlin-specific load
- `SnapshotStorageUsed` - Backup storage

### Query Performance

```python
# Use explain() to analyze queries
g.V().has('person', 'name', 'Alice').out('knows').explain()

# Monitor slow queries in CloudWatch Logs
# Enable audit logging: enable_audit_log = true in terraform.tfvars
```

## Security Best Practices

1. **IAM Authentication**: Enabled by default
   ```python
   # Use IAM auth for connections
   from neptune_python_utils.endpoints import Endpoints
   endpoints = Endpoints(neptune_endpoint=neptune_endpoint, iam_enabled=True)
   ```

2. **VPC Isolation**: Neptune is in private subnets only

3. **Encryption**:
   - Data at rest: Enabled with KMS
   - Data in transit: TLS/SSL required

4. **Network Access**: Only from SageMaker and EMR security groups

## Troubleshooting

### Connection Timeout

**Problem**: Cannot connect to Neptune from SageMaker

**Solutions**:
1. Verify security group allows port 8182:
   ```bash
   # Should show Neptune SG allows 8182 from SageMaker SG
   ```

2. Check Neptune cluster is available:
   ```bash
   aws neptune describe-db-clusters \
       --db-cluster-identifier your-neptune-cluster \
       --region us-gov-west-1 \
       --query 'DBClusters[0].Status'
   ```

3. Verify endpoint is correct:
   ```bash
   terraform output neptune_cluster_endpoint
   ```

### Slow Queries

**Problem**: Gremlin/SPARQL queries are slow

**Solutions**:
1. Add indexes (Neptune auto-indexes labels and IDs)
2. Limit traversal depth: `.repeat(__.out()).times(3)`
3. Use `.limit()` to restrict result sets
4. Consider read replicas for read-heavy workloads:
   ```hcl
   neptune_instance_count = 2  # Primary + read replica
   ```

### Out of Memory

**Problem**: Neptune instance running out of memory

**Solutions**:
1. Upgrade instance class:
   ```hcl
   neptune_instance_class = "db.r5.2xlarge"  # More RAM
   ```

2. Optimize queries to return less data
3. Use pagination for large result sets

## Cost Optimization

1. **Right-size instances**: Start with `db.r5.large`, scale up as needed
2. **Backup retention**: Balance retention vs. storage costs
3. **Read replicas**: Only add if read-heavy workload justifies cost
4. **Development**: Use single instance, enable multi-AZ only for production

## Next Steps

- [SageMaker Spaces with Graph Kernels](SAGEMAKER_SPACES_KERNELS.md)
- [EMR Setup Guide](SAGEMAKER_EMR_SETUP.md)
- [AWS Neptune Documentation](https://docs.aws.amazon.com/neptune/)
- [Gremlin Query Language](https://tinkerpop.apache.org/gremlin.html)
- [SPARQL 1.1 Query Language](https://www.w3.org/TR/sparql11-query/)
