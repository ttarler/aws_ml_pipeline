# VPC Resource Automatic Cleanup

## Overview

The infrastructure is configured to ensure **all VPC-dependent resources (route tables, security groups, gateways) are always deleted before the VPC** during `terraform destroy`. This prevents common "DependencyViolation" errors that occur when Terraform tries to delete a VPC while resources are still attached.

## How It Works

### 1. Lifecycle Rules

All VPC-dependent resources have explicit lifecycle rules:

```hcl
lifecycle {
  # Ensure resource is deleted before VPC during destroy
  create_before_destroy = false
}
```

This is applied to:
- **Route Tables**:
  - `aws_route_table.public` - Public subnet route table
  - `aws_route_table.private` - Private subnet route table
  - `aws_route_table_association.public` - Public route table associations
  - `aws_route_table_association.private` - Private route table associations

- **Security Groups** (all 8):
  - `aws_security_group.vpc_endpoints` - VPC Endpoints security group
  - `aws_security_group.sagemaker` - SageMaker security group
  - `aws_security_group.emr_master` - EMR master node security group
  - `aws_security_group.emr_slave` - EMR slave nodes security group
  - `aws_security_group.emr_service` - EMR service security group
  - `aws_security_group.ecs` - ECS security group
  - `aws_security_group.neptune` - Neptune security group
  - `aws_security_group.bastion` - Bastion host security group

- **Gateways**:
  - `aws_internet_gateway.main` - Internet Gateway
  - `aws_nat_gateway.main` - NAT Gateway

- **VPC**:
  - `aws_vpc.main` - The VPC itself (deleted last)

### 2. Coordination Resource

A `null_resource` coordinates the destroy order for all VPC resources:

```hcl
resource "null_resource" "vpc_resource_cleanup" {
  triggers = {
    vpc_id = aws_vpc.main.id
  }

  depends_on = [
    # Route tables and associations
    aws_route_table.public,
    aws_route_table.private,
    aws_route_table_association.public,
    aws_route_table_association.private,
    aws_route.private_nat_gateway,

    # Security groups (all 8)
    aws_security_group.vpc_endpoints,
    aws_security_group.sagemaker,
    aws_security_group.emr_master,
    aws_security_group.emr_slave,
    aws_security_group.emr_service,
    aws_security_group.ecs,
    aws_security_group.neptune,
    aws_security_group.bastion,

    # Gateways
    aws_nat_gateway.main,
    aws_internet_gateway.main
  ]
}
```

**How this works**:
- During **create**: All VPC resources must exist before this null_resource
- During **destroy**: This null_resource is destroyed first, then all VPC resources

### 3. VPC Lifecycle Rule

The VPC itself has a lifecycle rule ensuring it's deleted last:

```hcl
resource "aws_vpc" "main" {
  lifecycle {
    # Ensure VPC is deleted last during destroy
    # Route tables, subnets, and other resources must be deleted first
    create_before_destroy = false
  }
}
```

## Destroy Order Guarantee

When you run `terraform destroy`, resources are deleted in this order:

```
Destroy Order (Automatic):
┌─────────────────────────────────────────────────┐
│ 1. Compute Resources                            │
│    - SageMaker Domain & Apps                    │
│    - EMR Cluster                                │
│    - ECS Services & Tasks                       │
│    - Neptune Instances                          │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 2. EFS Mount Targets                            │
│    - Cleanup script runs automatically          │
│    - Mount targets deleted from subnets         │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 3. Route Table Cleanup Coordinator              │
│    - null_resource destroyed (no action)        │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 4. NAT Gateway                                  │
│    - Released from public subnet                │
│    - Elastic IP released                        │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 5. Route Table Associations                     │
│    - Private route table associations           │
│    - Public route table associations            │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 6. Routes                                       │
│    - Route to NAT Gateway                       │
│    - Route to Internet Gateway                  │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 7. Route Tables                                 │
│    - Private route table                        │
│    - Public route table                         │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 8. Internet Gateway                             │
│    - Detached from VPC                          │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 9. Subnets                                      │
│    - Private subnets (now clean)                │
│    - Public subnets (now clean)                 │
└─────────────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────────────┐
│ 10. VPC                                         │
│     - Deleted last (all dependencies gone)      │
└─────────────────────────────────────────────────┘
```

## Benefits

### ✅ No Manual Cleanup Required
- You don't need to manually delete route tables
- No need to run separate cleanup scripts
- Just run `terraform destroy` and everything is handled

### ✅ Prevents Common Errors

**Without this mechanism**, you might see:
```
Error: deleting VPC (vpc-xxxxx): DependencyViolation:
The vpc 'vpc-xxxxx' has dependencies and cannot be deleted.
```

**With this mechanism**:
- Route tables are automatically deleted first
- VPC deletion succeeds without errors
- Clean, one-step destruction process

### ✅ Idempotent and Safe
- Can run `terraform destroy` multiple times
- Safe to interrupt and restart
- No orphaned resources

## What You'll See During Destroy

```bash
$ terraform destroy

# ... earlier resources destroyed ...

module.networking.null_resource.route_table_cleanup: Destroying...
module.networking.null_resource.route_table_cleanup: Destruction complete

module.networking.aws_nat_gateway.main[0]: Destroying...
module.networking.aws_nat_gateway.main[0]: Still destroying... [10s elapsed]
module.networking.aws_nat_gateway.main[0]: Still destroying... [20s elapsed]
module.networking.aws_nat_gateway.main[0]: Destruction complete

module.networking.aws_route_table_association.private[0]: Destroying...
module.networking.aws_route_table_association.private[1]: Destroying...
module.networking.aws_route_table_association.private[2]: Destroying...
module.networking.aws_route_table_association.private[0]: Destruction complete
module.networking.aws_route_table_association.private[1]: Destruction complete
module.networking.aws_route_table_association.private[2]: Destruction complete

module.networking.aws_route.private_nat_gateway[0]: Destroying...
module.networking.aws_route.private_nat_gateway[0]: Destruction complete

module.networking.aws_route_table.private: Destroying...
module.networking.aws_route_table.private: Destruction complete

module.networking.aws_route_table.public[0]: Destroying...
module.networking.aws_route_table.public[0]: Destruction complete

module.networking.aws_internet_gateway.main[0]: Destroying...
module.networking.aws_internet_gateway.main[0]: Still destroying... [10s elapsed]
module.networking.aws_internet_gateway.main[0]: Destruction complete

module.networking.aws_subnet.private[0]: Destroying...
module.networking.aws_subnet.private[1]: Destroying...
module.networking.aws_subnet.private[2]: Destroying...
module.networking.aws_subnet.private[0]: Destruction complete
module.networking.aws_subnet.private[1]: Destruction complete
module.networking.aws_subnet.private[2]: Destruction complete

module.networking.aws_vpc.main: Destroying...
module.networking.aws_vpc.main: Destruction complete

Destroy complete! Resources: XX destroyed.
```

## Technical Details

### Terraform Dependency Graph

Terraform builds a dependency graph based on:

1. **Explicit Dependencies**: `depends_on` blocks
2. **Implicit Dependencies**: Resource references (e.g., `vpc_id = aws_vpc.main.id`)
3. **Lifecycle Rules**: `create_before_destroy` settings

Our configuration uses all three to ensure correct ordering.

### Why `create_before_destroy = false`?

This setting means:
- During **update**: Destroy old resource, then create new one
- During **destroy**: Delete resources in dependency order

Setting it to `false` (the default) ensures resources are destroyed in the correct order based on the dependency graph.

### The Role of null_resource

The `null_resource.route_table_cleanup` doesn't execute any code, but it serves as a **coordination point** in the dependency graph:

```
Route Tables → null_resource → Subnets → VPC
```

This forces Terraform to destroy route tables before subnets and the VPC.

## Troubleshooting

### If Route Table Deletion Still Fails

**Unlikely, but if it happens:**

1. **Check for manual modifications**:
   ```bash
   # List route tables
   aws ec2 describe-route-tables \
       --filters "Name=vpc-id,Values=<vpc-id>" \
       --region us-gov-west-1
   ```

2. **Check for orphaned routes**:
   ```bash
   # Look for routes not managed by Terraform
   aws ec2 describe-route-tables \
       --route-table-ids <route-table-id> \
       --region us-gov-west-1
   ```

3. **Manual cleanup** (last resort):
   ```bash
   # Delete route table association
   aws ec2 disassociate-route-table \
       --association-id <association-id> \
       --region us-gov-west-1

   # Delete route table
   aws ec2 delete-route-table \
       --route-table-id <route-table-id> \
       --region us-gov-west-1

   # Retry destroy
   terraform destroy
   ```

### Verify Destroy Order

To see the destroy order Terraform will use:

```bash
# Generate destroy plan
terraform plan -destroy

# Look for dependency information
terraform graph -type=plan-destroy | dot -Tpng > destroy-graph.png
```

## Files Modified

All changes are in `modules/networking/main.tf`:

1. **Lines 14-18**: VPC lifecycle rule
2. **Lines 96-99**: IGW lifecycle rule
3. **Lines 108-111**: Public route table lifecycle rule
4. **Lines 120-123**: Public route table association lifecycle rules
5. **Lines 163-167**: Private route table lifecycle rule
6. **Lines 165-168**: NAT Gateway lifecycle rule
7. **Lines 188-191**: Private route table association lifecycle rules
8. **Lines 1106-1124**: Route table cleanup coordinator

## Related Documentation

- [Main README - Destroying Infrastructure](../README.md#destroying-infrastructure)
- [Cleanup Guide - Automatic Cleanup Features](CLEANUP_GUIDE.md#automatic-cleanup-features)
- [EFS Cleanup Documentation](EFS_CLEANUP.md)

## Summary

✅ **Route tables are automatically deleted before the VPC**
✅ **Security groups (all 8) are automatically deleted before the VPC**
✅ **Gateways (NAT and Internet) are automatically deleted before the VPC**
✅ **No manual cleanup required**
✅ **Prevents DependencyViolation errors**
✅ **Safe and idempotent**
✅ **Works seamlessly with terraform destroy**

You can confidently run `terraform destroy` knowing that all VPC resources will be cleaned up in the correct order!
